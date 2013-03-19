// Written in the D programming language.

module linalg.debugging;

public import std.stdio;

import std.range;
import std.algorithm;

struct OutputProxy
{
    uint indentLevel = 0;
    uint silentLevel = 0;

    string opCast()
    {
        if(indentLevel > 0)
            return cast(string) reduce!("a ~ b")(repeat("    ", indentLevel));
        else
            return "";
    }

    string toString()
    {
        return cast(string) this;
    }

    void write(T...)(T args)
    {
        if(!silentLevel)
            std.stdio.write(this, args);
    }

    void writeln(T...)(T args)
    {
        if(!silentLevel)
            std.stdio.writeln(this, args);
    }

    void writefln(T...)(T args)
    {
        if(!silentLevel)
        {
            std.stdio.write(this);
            std.stdio.writefln(args);
        }
    }
}

public OutputProxy debugOP;

enum string debugIndentScope =
    "++debugOP.indentLevel; scope(exit) debug --debugOP.indentLevel;";

enum string debugSilentScope =
    "++debugOP.silentLevel; scope(exit) debug --debugOP.silentLevel;";
