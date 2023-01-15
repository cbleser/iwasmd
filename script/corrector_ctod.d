#!/usr/bin/rdmd

import std.getopt;
import std.stdio;
import std.format;
import std.array;
import std.regex;
import std.path;
import std.range;
import std.file : fwrite = write, fread = read, readText, isDir, isFile, getcwd, mkdirRecurse, exists, rename, dirEntries, SpanMode;
import std.exception : enforce;
import std.algorithm.iteration : map, uniq, each, filter, joiner;
import std.algorithm.searching : endsWith, canFind, commonPrefix, countUntil;
import process = std.process;

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
    enum module_regex = regex(`^\s*module\s+([^\;]+)`);
    enum import_regex = regex(`^\s*(private|public|protected|package)\s+(import)\s+([^\;]+)`);
    enum include_regex = regex(`^(\s*#include\s+)"(.*)"`);
    enum define_with_params_regex = regex(`^\s*#define\s+(\w+)\s*\(([^\)]*)\)`, "g");
    enum define_regex = regex(`^\s*#define\s+(\w+)`);
    enum comman_regex = regex(`,\s*`);
    enum continue_regex = regex(`\s*\\$`);
    enum line_comment_regex = regex(`^\s*//`);
    enum comment_begin_regex = regex(`^\s*/\*`);
    enum comment_end_regex = regex(`\*/`);

    /*
	Returns: the common srcroot between the default_path and the list of srcdirs
Ex.
	default_path "xxx/yyy/zzz" and srcdir=["xxx/zzz", "xxx/yyy"]
	returns "zzz"
*/
    static string commonSrcRoot(string default_path, const(string[]) srcdirs) {
        //auto default_path = filename.dirName;
        auto filepath_split = default_path.pathSplitter;
        foreach (dir; srcdirs) {
            auto dir_split = dir.pathSplitter;
            const srcroot = dir_split.commonPrefix(filepath_split);
            if (srcroot.length == dir_split.walkLength) {
                return filepath_split.dropExactly(srcroot.length).buildPath;
            }
        }
        return default_path;
    }

    int precorrect(File fout, const(string[]) srcdirs, const bool d_source = false) { //File file, string[] config.replaces, const(string[]) includes) {
        bool comment;
        bool comment_first_line;
        bool continue_line;
        bool in_macro;
        bool keep_macro;
        bool have_module;
        const file_path = commonSrcRoot(filename, srcdirs).dirName;
        if (verbose) {
            writefln("file_path=%s", file_path);
        }
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
            if (d_source && !have_module) {
                auto m = line.matchFirst(module_regex);
                if (!m.empty) {
                    writefln("Module %s", m);
                    have_module = true;
                }

            }
            { // comment begin '/*'
                auto m = line.matchFirst(comment_begin_regex);
                if (!m.empty) {
                    comment = true;
                    if (verbose) {
                        fout.writefln("Match %s", m);
                    }
                }

            }
            if (comment) { // comment end  '*/'
                auto m = line.matchFirst(comment_end_regex);
                if (!m.empty) {
                    if (verbose) {
                        fout.writefln("Match %s", m);
                    }
                    comment = false;
                }
                fout.writefln("%s", line);
                continue;

            }
            { // single line comment '//'
                auto m = line.matchFirst(line_comment_regex);
                if (!m.empty) {

                    if (verbose)
                        fout.writefln("Match %s", m);
                    continue;
                }

            }

            { // #define NAME
                auto m = line.matchFirst(define_regex);
                if (!m.empty && !config.isMacroDeclared(m[1])) {
                    keep_single_line_macro = config.keep_single;
                    keep_macro = config.includeMacro(m[1]);

                }
            }
            { // extend line '\'
                auto m = line.matchFirst(continue_regex);
                continue_line = !m.empty;
                if (continue_line) {
                    if (verbose)
                        fout.writefln("Match %s", m);
                    if (remove_line_extend)
                        line = m.pre;
                }
                keep_macro &= continue_line;
            }
            if (d_source) {
                auto m = line.matchFirst(import_regex);
            }
            else { // include statement '#include'
                auto m = line.matchFirst(include_regex);
                if (!m.empty) {

                    if (verbose)
                        fout.writefln("Match %s", m);
                    fout.writefln(`%s "%s"`, m[1], asNormalizedPath(buildPath(file_path, m[2])));
                    continue;
                }
            }
            if (!keep_single_line_macro) { // define marcros with arguments '#define NAME(<arg>, ...)'
                auto m = line.matchFirst(define_with_params_regex);
                if (!m.empty) {
                    if (verbose)
                        fout.writefln("Match %s", m);

                    const macro_name = m[1];

                    fout.writefln("// %s", line);
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
            fout.writefln("%s", line);
            if (in_macro && !continue_line) {
                in_macro = false;
                fout.writeln("}");
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
    string outdir; /// Output directory
    string packagename; /// Package name
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
        json[outdir.stringof.basename] = outdir;
        json[packagename.stringof.basename] = packagename;
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
        outdir = json[outdir.stringof.basename].str;
        packagename = json[packagename.stringof.basename].str;
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

enum json_ext = ".json";
enum tmp_ext = ".tmp";
enum d_ext = ".d";
enum c_ext = ".c";
enum h_ext = ".h";

void dryPrint(string[] filenames) {
    static string env(string filename) {
        const index = [c_ext, h_ext, d_ext].countUntil!(ext => filename.endsWith(ext));
        if (index < 0) {
            return "FILES";
        }
        return ["# FILES", "C_SRC_FILES", "H_SRC_FILES", "D_SRC_FILES"][index + 1];
    }

    filenames.each!(file => writefln("%s += %s", env(file), file));
}

immutable keywords = [
    "bool",
    "byte",
    "ubyte",
    "short",
    "ushort",
    "int",
    "uint",
    "long",
    "ulong",
    "cent",
    "ucent",
    "char",
    "wchar",
    "dchar",
    "float",
    "double",
    "real",
    "ifloat",
    "idouble",
    "ireal",
    "cfloat",
    "cdouble",
    "creal",
    "void",
    "abstract",
    "alias",
    "align",
    "asm",
    "assert",
    "auto",

    "body",
    "bool",
    "break",
    "byte",

    "case",
    "cast",
    "catch",
    "cdouble",
    "cent",
    "cfloat",
    "char",
    "class",
    "const",
    "continue",
    "creal",

    "dchar",
    "debug",
    "default",
    "delegate",
    "delete",
    "deprecated",
    "do",
    "double",

    "else",
    "enum",
    "export",
    "extern",

    "false",
    "final",
    "finally",
    "float",
    "for",
    "foreach",
    "foreach_reverse",
    "function",

    "goto",

    "idouble",
    "if",
    "ifloat",
    "immutable",
    "import",
    "in",
    "inout",
    "int",
    "interface",
    "invariant",
    "ireal",
    "is",

    "lazy",
    "long",

    "macro",
    "mixin",
    "module",

    "new",
    "nothrow",
    "null",

    "out",
    "override",

    "package",
    "pragma",
    "private",
    "protected",
    "public",
    "pure",

    "real",
    "ref",
    "return",

    "scope",
    "shared",
    "short",
    "static",
    "struct",
    "super",
    "switch",
    "synchronized",

    "template",
    "this",
    "throw",
    "true",
    "try",
    "typeid",
    "typeof",

    "ubyte",
    "ucent",
    "uint",
    "ulong",
    "union",
    "unittest",
    "ushort",

    "version",
    "void",

    "wchar",
    "while",
    "with",

    "__FILE__",
    "__FILE_FULL_PATH__",
    "__MODULE__",
    "__LINE__",
    "__FUNCTION__",
    "__PRETTY_FUNCTION__",

    "__gshared",
    "__traits",
    "__vector",
    "__parameters",

];

/**
	Returns: converts a filepath to a valid d-file path
	Note replaces - with _
*/
string correctDPath(string filename) {
    return filename
        .replace("-", "_")
        .pathSplitter
        .map!((pathbit) {
            const index = keywords.countUntil(pathbit);
            if (index < 0)
                return pathbit;
            return keywords[index] ~ "_";
        })
        .buildPath;
}

enum deps_makefile = "deps.mk";
enum config_makefile = "config.mk";
void makeDeps(string[] filenames, const(Config) config, const(string[]) srcdirs, const bool force) {
    import std.ascii : toUpper, toLower;
    import std.conv : to;

    bool[string] make_env;
    enum TARGET_CFILES = "TARGET_CFILES";
    enum TARGET_DFILES = "TARGET_DFILES";
    enum SRC_CFILES = "SRC_CFILES";
    enum ALL_DTARGETS = "ALL_DTARGETS";

    make_env[TARGET_CFILES] = true;
    make_env[SRC_CFILES] = true;

    auto fout = File("deps.mk", "w");
    scope (exit) {
        fout.close;
    }
    const generate_config_makefile = force || !config_makefile.exists;
    File config_fout;
    if (generate_config_makefile) {
        config_fout = File(config_makefile, "w");
    }
    scope (exit) {
        config_fout.close;
    }
    string new_env(string name, string prefix = null) {
        string result;
        string nextName(string str) {
            if ((str in make_env) !is null) {
                alias name_format = format!("%s%s_%s", string, string, uint);
                enum name_regex = regex(`^(\w+)_(\d+)$`);
                auto m = str.matchFirst(name_regex);
                return (m.empty) ? name_format(prefix, str, 1) : name_format(prefix, m[1], m[2].to!uint + 1);
            }
            return str;
        }

        for (result = name.baseName.stripExtension.map!(c => cast(char) toUpper(c)).array; (result in make_env) !is null;
                result = nextName(
                    result)) {
            /// empty
        }
        make_env[result] = true;
        return result;
    }

    foreach (filename; filenames) {
        const dest_cfile = config.outdir.buildPath(Corrector.commonSrcRoot(filename, srcdirs)).correctDPath;

        const dest_dfile = dest_cfile.setExtension(d_ext);
        fout.writeln("#");
        fout.writefln("# target %s", dest_dfile);
        fout.writeln("#");

        fout.writefln("%s := %s", new_env(dest_cfile, "c_"), dest_cfile);
        fout.writefln("%s += %s", TARGET_CFILES, dest_cfile);
        const dtarget_file_env = new_env(dest_dfile);
        fout.writefln("%s := %s", dtarget_file_env, dest_dfile);
        fout.writefln("%s += %s", TARGET_DFILES, dest_dfile);
        fout.writeln;

        fout.writefln("%s: %s", dest_cfile, filename);
        fout.writeln;

        fout.writefln("%s: %s", dest_dfile, dest_cfile);
        fout.writeln;

        const dtarget = dtarget_file_env.map!(c => cast(char) c.toLower).array;

        fout.writefln("%s: $(%s)", dtarget, dtarget_file_env);
        fout.writeln;
        fout.writefln("%s += %s", ALL_DTARGETS, dtarget);

        if (generate_config_makefile) {
            config_fout.writeln("#");
            config_fout.writefln("# Setup for %s", dest_dfile);
            config_fout.writeln("#");
            config_fout.writefln("%s:", dtarget);
            config_fout.writeln;
        }
    }
    if (generate_config_makefile) {
        config_fout.writefln("all_ctod: $(%s)", ALL_DTARGETS);
        config_fout.writeln;
    }

}

int main(string[] args) {
    immutable program = "corrector_ctod";
    string[] paths;
    Config config;
    string config_file;
    string indir;
    string infilter = "*.[ch]";
    // string[] config.replaces;
    bool verbose;
    bool overwrite;
    bool insert;
    bool dry;
    bool deps;
    bool force;
    int errors;
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
                "od", "Output directory (Default stdout)", &(config.outdir),
                "is", "Input source directory", &indir,
                "filter", format("Input source-file filter used with -is (Default : %s)", infilter), &infilter,
                "n|dry", "Dry-run does not produce output just list the files", &dry,
                "deps", "Writes and make dependency file", &deps,
                "f", format("Force overwrite of %s", config_makefile), &force,
                "p|package", "Sets the common d-module package", &(
                    config.packagename),
                "i", "Overrite input files (Only for d-files)", &insert,
                "O", "Overwrites config file", &overwrite,
                "config", "g file to be overwritter", &config_file,

        );

        if (main_args.helpWanted) {
            defaultGetoptPrinter([
                "Documentation: https://tagion.org/",
                "",
                "Usage:",
                format("%s [<option>...] [<src-roots>] <c-source>", program),
                "",
                "<option>:",
            ].join("\n"), main_args.options);
            return 0;
        }
        auto dirs = args[1 .. $]
            .filter!(file => file.isDir);
        const srcdirs = (dirs.empty) ? [getcwd] : dirs.array;

        auto filenames = args[1 .. $]
            .filter!(file => file.isFile)
            .array;

        if (!indir.empty) {
            //	const filter_regex=regex(infilter);

            filenames ~= indir //.dirEntries(filter_regex, SpanMode.depth)
                .dirEntries(infilter, SpanMode.depth)
                .filter!(file => file.isFile)
                .map!(file => file.name)
                .array;

        }

        if (config_file.length && !config_file.endsWith(json_ext)) {
            stderr.writefln("Config file %s must have a %s extension", config_file, json_ext);
        }
        /// Loads all config files into one config
        filenames
            .filter!(f => f.endsWith(json_ext))
            .map!(f => Config(f))
            .each!(conf => config.accumulate(conf));

        if (overwrite) {
            //string ext_JSON=ext.JSON.to!string;
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

        //const included = allIncludes(paths);
        if (dry) {
            dryPrint(filenames);
            if (!deps)
                return 0;
        }
        if (deps) {
            makeDeps(filenames, config, srcdirs, force);
            return 0;
        }
        File fout = stdout;
        foreach (filename; filenames) {
            const d_source = filename.endsWith(d_ext);
            const overwrite_source = insert && d_source && config.outdir.empty;
            string outfilename;
            if (insert) {
                outfilename = filename.setExtension(tmp_ext);
            }
            else if (!config.outdir.empty) {
                outfilename = config.outdir.buildPath(Corrector.commonSrcRoot(filename, srcdirs));
                const outpath = outfilename.dirName;
                if (!outpath.exists) {
                    outpath.mkdirRecurse;
                }
            }
            if (!outfilename.empty) {
                fout = File(outfilename, "w");
            }
            scope (exit) {
                if (fout !is stdout) {
                    fout.close;
                }
            }

            errors += Corrector(filename, config, verbose).precorrect(fout, srcdirs, d_source);
            if (overwrite_source) {
                rename(outfilename, filename);
            }
        }
    }
    catch (Exception e) {
        stderr.writefln("Error: %s", e.msg);
        return -1;
    }

    return errors;
}
