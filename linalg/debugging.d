// Written in the D programming language.

module linalg.debugging;

public import std.stdio;

import std.range;
import std.algorithm;

struct Indentation
{
    size_t level = 0;

    void add() pure
    {
        ++level;
    }

    void rem() pure
        in
        {
            assert(level > 0);
        }
    body
    {
        --level;
    }

    string opCast()
    {
        if(level > 0)
            return cast(string) reduce!("a ~ b")(repeat("  ", level));
        else
            return "";
    }

    string toString()
    {
        return cast(string) this;
    }

    void write(T...)(T args)
    {
        std.stdio.write(this, args);
    }

    void writeln(T...)(T args)
    {
        std.stdio.writeln(this, args);
    }

    void writefln(T...)(T args)
    {
        std.stdio.write(this);
        std.stdio.writefln(args);
    }
}

public Indentation indent;

unittest
{
    Indentation ind;
    assert(cast(string) ind == "");
    ind.add();
    assert(cast(string) ind == "  ");
    ind.add();
    assert(cast(string) ind == "    ");
    ind.rem();
    assert(cast(string) ind == "  ");
}
