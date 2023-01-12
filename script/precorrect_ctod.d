#!/usr/bin/rdmd

import std.getopt;
import std.stdio;
import std.format;
import std.array;
import std.regex;

void precorrect(File file) {
    enum include_regex = regex(`^\s*(#include)\s+".*"`);
    enum define_regex = regex(`^\s*#define\s+(\w+)\s*\(((.*),)*(.*)\)`);
    enum continue_regex = regex(`\s*\\$`);
    enum line_comment_regex = regex(`^\s*//`);
    enum comment_begin_regex = regex(`^\s*/\*`);
    enum comment_end_regex = regex(`\*/`);
    bool comment;
    bool comment_first_line;
    bool continue_line;
    foreach (line; file.byLine) {
       writefln("<%s>", line);
		{
            auto m = line.matchFirst(comment_begin_regex);
            if (!m.empty) {
                comment = true;
                writefln("/*m=%s", m);
                //    writefln("%s", line);
            }

        }
        if (comment) {
            auto m = line.matchFirst(comment_end_regex);
            writefln("*/m=%s", m);
            writefln("%s", line);
            if (!m.empty) {
                comment = false;
            }
            continue;

        }
        {
            auto m = line.matchFirst(continue_regex);
            continue_line = !m.empty;
            if (continue_line) {
                writefln("m=%s", m);
                writefln("define -> %s", m.pre);
                line = m.pre;
                //                continue;
            }
        }
        {
            auto m = line.matchFirst(line_comment_regex);
            if (!m.empty) {

                writefln("m=%s", m);
                writefln("comment -> %s", line);
                //    writefln("%s", line);
                continue;
            }

        }

        {
            auto m = line.matchFirst(include_regex);
            if (!m.empty) {

                writefln("m=%s", m);
                writefln("include -> %s", line);
                continue;
            }
        }
        {
            auto m = line.matchFirst(define_regex);
            if (!m.empty) {

                writefln("define -> %s....", line);
            }
        }

        writefln(":%s", line);
    }
}

int main(string[] args) {
    immutable program = "precorrect";
    string[] paths;
    try {
        auto main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "I", "Include directory", &paths, //		std.getopt.config.bundling,

                

        );
        if (main_args.helpWanted) {
            defaultGetoptPrinter([
                "Documentation: https://tagion.org/",
                "",
                "Usage:",
                format("%s [<option>...]", program),
                "",
                "<option>:",
            ].join("\n"), main_args.options);
            return 0;
        }
        writefln("%s", args[1 .. $]);
        foreach (filename; args[1 .. $]) {
            auto file = File(filename);
            precorrect(file);
            scope (exit) {
                file.close;
            }
        }
    }
    catch (Exception e) {
        stderr.writeln("%s", e);
        return 1;
    }

    return 0;
}
