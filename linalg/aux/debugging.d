// Written in the D programming language.

/**
 * This module contains structure that allows indent debug output making it
 * more readable.
 *
 * The output using this structure can be suppressed to avoid flood coming from
 * code known to be correct.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013-2014, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.aux.debugging;

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
        string result = "linalg: ";
        if(indentLevel > 0)
            result ~= cast(string) reduce!("a ~ b")(repeat("    ", indentLevel));
        return result;
    }

    string toString()
    {
        return cast(string) this;
    }

    void write(T...)(T args)
    {
        if(!__ctfe)
            if(!silentLevel)
                std.stdio.write(this, args);
    }

    void writeln(T...)(T args)
    {
        if(!__ctfe)
            if(!silentLevel)
                std.stdio.writeln(this, args);
    }

    void writefln(T...)(T args)
    {
        if(!__ctfe)
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

/*
 * dfo = Debug Formatted Output
 */
void dfMemAbandon(T)(T[] a)
{
    if(!__ctfe)
        if(a) debugOP.writefln("mem.abandon: %s", dfsArray(a));
}

void dfMemReferred(T)(T[] a)
{
    if(!__ctfe)
        if(a) debugOP.writefln("mem.referred: %s", dfsArray(a));
}

void dfMemAllocated(T)(T[] a)
{
    if(!__ctfe)
        if(a) debugOP.writefln("mem.allocated: %s", dfsArray(a));
}

void dfMemCopied(T)(T[] a, T[] b)
{
    if(!__ctfe)
        if(a) debugOP.writefln("mem.copied: %s -> %s",
                               dfsArray(a), dfsArray(b));
}

void dfoOp1(T)(string op, T[] a)
{
    if(!__ctfe)
        if(a) debugOP.writefln("op.%s: %s", op, dfsArray(a));
}

void dfoOp2(Ta, Tb)(string op, Ta[] a, Tb[] b)
{
    if(!__ctfe)
        if(a) debugOP.writefln("op.%s: %s -> %s", op,
                               dfsArray(a), dfsArray(b));
}

void dfoOp3(Ta, Tb, Tc)(string op, Ta[] a, Tb[] b, Tc[] c)
{
    if(!__ctfe)
        if(a) debugOP.writefln("op.%s: %s, %s -> %s", op,
                               dfsArray(a), dfsArray(b), dfsArray(c));
}
