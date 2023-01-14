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

struct MacroDeclaration {
    enum macro_args_regex = regex(`(\w+):(\w*)\(([^\)]+)\)`);
    Regex!char name_regex;
    string return_type;
    string[] param_types;
    this(string macro_declaration) {
        auto m = macro_declaration.matchFirst(macro_args_regex);
        name_regex = regex(m[1]);
        return_type = m[2]; //.length) ? m[2] : void.stringof;
        param_types = m[3].splitter(Corrector.comman_regex).array;

    }
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
    Config config;
    //   const(string[]) config.replaces; /// config.replaces pattern
    const bool verbose;
    enum include_regex = regex(`^(\s*#include\s+)"(.*)"`);
    enum define_with_params_regex = regex(`^\s*#define\s+(\w+)\s*\(([^\)]*)\)`, "g");
    enum define_regex = regex(`^\s*#define\s+(\w+)`);
    enum comman_regex = regex(`,\s*`);
    enum continue_regex = regex(`\s*\\$`);
    enum line_comment_regex = regex(`^\s*//`);
    enum comment_begin_regex = regex(`^\s*/\*`);
    enum comment_end_regex = regex(`\*/`);

    int precorrect() { //File file, string[] config.replaces, const(string[]) includes) {
        bool comment;
        bool comment_first_line;
        bool continue_line;
        bool in_macro;
        bool keep_macro;
        const file_path = filename.dirName;
        bool remove_line_extend() {
            return !keep_macro;
        }

        auto file = File(filename);
        scope (exit) {
            file.close;
        }
        int errors = config.prepare;
        if (errors) {
            return errors;
        }
        foreach (line; file.byLine) {
            bool keep_single_line_macro;
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

            { // #define NAME
                auto m = line.matchFirst(define_regex);
                if (!m.empty && !config.isMacroDeclared(m[1])) {
                    keep_single_line_macro = true;
                    keep_macro = config.includeMacro(m[1]);

                }
            }
            { // extend line '\'
                auto m = line.matchFirst(continue_regex);
                continue_line = !m.empty;
                if (continue_line) {
                    if (verbose)
                        writefln("Match %s", m);
                    if (remove_line_extend)
                        line = m.pre;
                }
                keep_macro &= continue_line;
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
            if (!keep_single_line_macro) { // define marcros with arguments '#define NAME(<arg>, ...)'
                auto m = line.matchFirst(define_with_params_regex);
                if (!m.empty) {
                    if (verbose)
                        writefln("Match %s", m);

                    const macro_name = m[1];

                    //				if (macro_name.matchFirst(config.macro_exclu
                    writefln("// %s", line);
                    const change_macro_params = config.macroDeclaration(macro_name);
                    const no_change = change_macro_params is change_macro_params.init;
                    string return_type() {
                        if (no_change ||
                                change_macro_params.return_type.length is 0) {
                            return void.stringof;
                        }
                        return change_macro_params.return_type;
                    }

                    string param_name(const size_t index) {
                        if (no_change ||
                                (index >= change_macro_params.param_types.length)) {
                            return format("param_%d", index);
                        }
                        return change_macro_params.param_types[index];
                    }

                    auto param_list = m[2]
                        .splitter(comman_regex)
                        .enumerate
                        .map!(p => format("%s %s", param_name(p.index), p.value));

                    line = format("%s %s(%-(%s, %))) ", return_type, macro_name, param_list).dup;
                    //line = _line;
                    in_macro = continue_line;
                    if (in_macro) {

                        line ~= " {";
                    }
                }
            }

            foreach (rep; config.replaces_regex) {
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
    string[] includes; /// Include paths
    string[] macros;
    string[] keep_macros;
    bool keep_single;
    ReplaceRegex[] replaces_regex;
    MacroDeclaration[] macro_declarations;
    //	RegEx!char[] macro_enabled_regex;
    size_t keep_macros_length;
    Regex!char keep_macros_regex;

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
        json[macros.stringof.basename] = macros;
        json[keep_macros.stringof.basename] = keep_macros;
        json[keep_single.stringof.basename] = keep_single;
        filename.fwrite(json.toPrettyString);
    }

    void load(string filename) {
        auto json = filename.readText.parseJSON;

        replaces = json[replaces.stringof.basename].array
            .map!(j => j.str)
            .array;
        macros = json[macros.stringof.basename].array
            .map!(j => j.str)
            .array;
        keep_macros = json[keep_macros.stringof.basename].array
            .map!(j => j.str)
            .array;
        keep_single = json[keep_single.stringof.basename].boolean;

    }

    const(MacroDeclaration) macroDeclaration(const(char[]) name) const {
        foreach (macro_decl; macro_declarations) {
            if (!name.matchFirst(macro_decl.name_regex).empty) {
                return macro_decl;
            }
        }
        return MacroDeclaration.init;
    }

    bool isMacroDeclared(const(char[]) name) const {
        return macroDeclaration(name) !is MacroDeclaration.init;
    }

    bool includeMacro(const(char[]) name) const {
        return ((keep_macros_regex !is Regex!char.init) &&
                !name.matchAll(keep_macros_regex).empty);
    }

    int prepare() {
        int errors;
        if (replaces_regex.length !is replaces.length) {
            replaces_regex.length = replaces.length;
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
        }
        if (macro_declarations.length !is macros.length) {
            macro_declarations.length = macros.length;
            foreach (i, macro_; macros) {
                try {
                    macro_declarations[i] = MacroDeclaration(macro_);
                }
                catch (Exception e) {
                    errors++;
                    stderr.writefln("Error: in macro declaration %s", macro_);
                    stderr.writefln("%s", e.msg);
                }
            }
        }
        if (keep_macros_length !is keep_macros.length) {
            keep_macros_length = keep_macros.length;
            try {
                keep_macros_regex = regex(keep_macros);
            }
            catch (RegexException e) {
                errors++;
                stderr.writefln("Error: exclude macro %s", keep_macros);
                stderr.writefln("%s", e.msg);
            }

        }
        return errors;
    }
}

int main(string[] args) {
    immutable program = "corrector_ctod";
    string[] paths;
    Config config;
    string config_file;
    // string[] config.replaces;
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
                "s", "Regex substitute (/<regex>/<to with $ param>/x) (x=g,i,x,s,m)",
                &(config.replaces),
                "m", "Set the parameter types for a macro -m<macro-name>:<return-type>(<param-type>,...) ",
                &(config.macros),
                "k", "Keep macros <regex-macro>", &(config.keep_macros),
                "E|enum", "Keep single line macro (Often enum declaration)", &(config.keep_single),
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
        writefln("%s", config.macros);
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
            errors += Corrector(filename, config, verbose).precorrect;
        }
    }
    catch (Exception e) {
        stderr.writefln("Error: %s", e.msg);
        return -1;
    }

    return errors;
}
