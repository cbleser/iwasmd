#!/usr/bin/rdmd

import std.getopt;
import std.stdio;
import std.format;
import std.array;
import std.regex;
import std.path;
import std.range;
import std.file : fwrite = write, fread = read, readText;
import std.exception : enforce;
import std.algorithm.iteration : map, uniq, each, filter, joiner;
import std.algorithm.searching : endsWith, canFind;

struct ReplaceRegex {
    enum regex_sub_split = regex(`^\/(.*)\/(.*)/(\w*)`);

    this(string replace) {
        auto m = replace.matchFirst(regex_sub_split);
        enforce(!m.empty, format("%s bad replace format", replace));
        re = regex(m[1], m[3]);
        to = m[2];
        //    option = m[3];
    }

    Regex!char re;
    string to;
    string option;
}

const(string[]) allIncludes(string[] paths) {
    import std.file;
    import std.path;

    return paths
        .map!(path => path.dirEntries(SpanMode.depth))
        .joiner
        .filter!(file => file.isFile)
        .filter!(file => file.name.endsWith(".h"))
        .filter!(file => file.name)
        .map!(file => file.name)

        .uniq
        .array;
}

struct Corrector {
    string filename; /// Source filename
    const(string[]) replaces; /// replaces pattern
    const(string[]) includes; /// Include paths
    const bool verbose;

    int precorrect() { //File file, string[] replaces, const(string[]) includes) {
        enum include_regex = regex(`^(\s*#include\s+)"(.*)"`);
        enum define_regex = regex(`^\s*#define\s+(\w+)\s*\(([^\)]*)\)`, "g");
        enum comman_regex = regex(`,\s*`);
        enum continue_regex = regex(`\s*\\$`);
        enum line_comment_regex = regex(`^\s*//`);
        enum comment_begin_regex = regex(`^\s*/\*`);
        enum comment_end_regex = regex(`\*/`);
        bool comment;
        bool comment_first_line;
        bool continue_line;
        bool in_macro;
        ReplaceRegex[] replaces_regex;
        replaces_regex.length = replaces.length;
        const file_path = filename.dirName;
        auto file = File(filename);
        scope (exit) {
            file.close;
        }
        int errors;
        foreach (i, replace; replaces) {
            try {
                replaces_regex[i] = ReplaceRegex(replace);
            }
            catch (RegexException e) {
                errors++;
                stderr.writefln("Error: in regex %s", replace);
                stderr.writefln("%s", e.msg);
            }
        }
        if (errors) {
            return errors;
        }
        foreach (line; file.byLine) {
            { // comment begin '/*'
                auto m = line.matchFirst(comment_begin_regex);
                if (!m.empty) {
                    comment = true;
                    if (verbose)
                        writefln("Match %s", m);
                }

            }
            if (comment) { // comment end  '*/'
                auto m = line.matchFirst(comment_end_regex);
                if (!m.empty) {
                    if (verbose)
                        writefln("Match %s", m);
                    comment = false;
                }
                writefln("%s", line);
                continue;

            }
            { // single line comment '//'
                auto m = line.matchFirst(line_comment_regex);
                if (!m.empty) {

                    if (verbose)
                        writefln("Match %s", m);
                    continue;
                }

            }

            { // extend line '\'
                auto m = line.matchFirst(continue_regex);
                continue_line = !m.empty;
                if (continue_line) {
                    if (verbose)
                        writefln("Match %s", m);
                    line = m.pre;
                }
            }
            { // include statement '#include'
                auto m = line.matchFirst(include_regex);
                if (!m.empty) {

                    if (verbose)
                        writefln("Match %s", m);
                    writefln(`%s "%s"`, m[1], asNormalizedPath(buildPath(file_path, m[2])));
                    continue;
                }
            }
            { // define marcros with arguments '#define NAME(<arg>, ...)'
                auto m = line.matchFirst(define_regex);
                if (!m.empty) {
                    if (verbose)
                        writefln("Match %s", m);
                    writefln("// %s", line);
				auto param_list=m[2]
				.splitter(comman_regex)
				.enumerate
				.map!(p => format("param_%d %s", p.index, p.value)); 

                    //writefln("void %s(%-(%s, %)) ", m[1], m[2].splitter(comman_regex));
                    auto _line = format("void %s(%-(%s, %))) ", m[1], param_list).dup;
                    pragma(msg, typeof(_line));
                    //writeln(_line);
                    line = _line;
                    in_macro = continue_line;
                    if (in_macro) {

                        line ~= " {";
                    }
                }
            }

            foreach (rep; replaces_regex) {
                line = replace(line, rep.re, rep.to);
            }
            writefln("%s", line);
            if (in_macro && !continue_line) {
                in_macro = false;
                writeln("}");
            }
        }
        return errors;
    }
}

string basename(string name) {
    return name.split(".").tail(1).front;
}

struct Config {
    import std.json;

    string[] replaces;
    this(string filename) {
        load(filename);
    }

    void accumulate(const(Config) conf) {
        conf.replaces
            .filter!(rep => !replaces.canFind(rep))
            .each!(rep => replaces ~= rep);
    }

    void save(string filename) {
        JSONValue json;
        json[replaces.stringof.basename] = replaces;
        filename.fwrite(json.toPrettyString);
    }

    void load(string filename) {
        auto json = filename.readText.parseJSON;

        replaces = json[replaces.stringof.basename].array
            .map!(j => j.str)
            .array;

    }

}

int main(string[] args) {
    immutable program = "precorrect";
    string[] paths;
    Config config;
    string config_file;
    // string[] replaces;
    bool verbose;
    bool overwrite;
    int errors;
    enum json_ext = ".json";
    try {
        auto main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "I", "Include directory", &paths, //		std.getopt.config.bundling,
                "v|verbose", "Verbose switch", &verbose,
                "s", "Regex substitute (/<regex>/<to with $ param>/x) (x=g,i,x,s,m)", &(config.replaces),
                "O", "Overwrites config file", &overwrite,
                "f", "Config file to be overwritter", &config_file,
        );
        if (main_args.helpWanted) {
            defaultGetoptPrinter([
                "Documentation: https://tagion.org/",
                "",
                "Usage:",
                format("%s [<option>...] <c-source>", program),
                "",
                "<option>:",
            ].join("\n"), main_args.options);
            return 0;
        }
        writefln("config_file=%s", config_file);
        const filenames = args[1 .. $];
        if (config_file.length && !config_file.endsWith(json_ext)) {
            stderr.writefln("Config file %s must have a %s extension", config_file, json_ext);
        }
        /// Loads all config files into one config
        filenames
            .filter!(f => f.endsWith(json_ext))
            .map!(f => Config(f))
            .each!(conf => config.accumulate(conf));

        if (overwrite) {
            auto list_of_configs =
                ((config_file.length is 0) ? filenames : [config_file])
                .filter!(f => f.endsWith(json_ext));

            // overwrite all the configs into files with .json extension
            list_of_configs
                .map!(f => f.setExtension(json_ext))
                .each!(f => config.save(f));
            list_of_configs.each!(c => writefln("Overwrite file '%s'", c));
            return 0;
        }
        // writefln("%s", args[1 .. $]);

        //const included = allIncludes(paths);
        foreach (filename; args[1 .. $]) {
            errors += Corrector(filename, config.replaces, paths, verbose).precorrect;
        }
    }
    catch (Exception e) {
        stderr.writefln("Error: %s", e.msg);
        return -1;
    }

    return errors;
}
