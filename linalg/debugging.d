// Written in the D programming language.

/**
 * This module contains structure that allows indent debug output making it
 * more readable.
 *
 * The output using this structure can be suppressed to avoid flood coming from
 * code known to be correct.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.debugging;

public import std.stdio;

import std.range;
import std.algorithm;
import std.format;

/**
 * Structure that translate calls of output functions adding indentation
 * or ignoring the call if output is suppressed.
 *
 * Examples:
 * ---
 * debug(unittests)
 * {
 *     debugOP.writeln("blahblahblah");
 *     mixin(debugIndentScope);
 *     debugOP.writeln("this will be indented");
 * }
 * ---
 */
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
        static if(!__ctfe)
            if(!silentLevel)
                std.stdio.write(this, args);
    }

    void writeln(T...)(T args)
    {
        static if(!__ctfe)
            if(!silentLevel)
                std.stdio.writeln(this, args);
    }

    void writefln(T...)(T args)
    {
        static if(!__ctfe)
            if(!silentLevel)
            {
                std.stdio.write(this);
                std.stdio.writefln(args);
            }
    }
}

/**
 * Instance of $(D OutputProxy) that is affected by following strings
 */
public OutputProxy debugOP;

/**
 * Mixin this string to increase indentation level of all output until the end
 * of current scope
 */
enum string debugIndentScope =
    "++debugOP.indentLevel; scope(exit) debug --debugOP.indentLevel;";

/**
 * Mixin this string to suppress all output until the end of current scope
 */
enum string debugSilentScope =
    "++debugOP.silentLevel; scope(exit) debug --debugOP.silentLevel;";

/**
 * Mixin this string to outline unittest block
 */
string debugUnittestBlock(string name)
{
    return "debug(unittests) {"
        "debugOP.writeln(__MODULE__ ~ \" unittest: " ~ name ~ "\");"
        "mixin(debugIndentScope);"
        "} else debug mixin(debugSilentScope);";
}

/**
 * Debug info output
 */
string dfsArray(T)(T[] a)
{
    auto writer = appender!string();
    formattedWrite(writer, "%x:%dx%d", cast(ulong)a.ptr, a.length, T.sizeof);
    return writer.data;
}

void dfMemAbandon(T)(T[] a)
{
    if(a) debugOP.writefln("memory abandon: %s", dfsArray(a));
}

void dfMemReferred(T)(T[] a)
{
    if(a) debugOP.writefln("memory referred: %s", dfsArray(a));
}

void dfMemAllocated(T)(T[] a)
{
    if(a) debugOP.writefln("memory allocated: %s", dfsArray(a));
}

void dfMemCopied(T)(T[] a, T[] b)
{
    if(a) debugOP.writefln("memory copied: %s -> %s",
                           dfsArray(a), dfsArray(b));
}
