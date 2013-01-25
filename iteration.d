// Written in the D programming language.

module iteration;

import std.range;

debug import std.stdio;

void copy(Tsource, Tdest)(Tsource source, Tdest dest)
    if(isInputRange!Tsource && isInputRange!Tdest)
{
    foreach(ref d; dest)
    {
        d = source.front;
        source.popFront();
    }
}

unittest
{
    int[] a = [1, 2, 3];
    int[] b = [0, 0, 0];
    copy(a, b);
    assert(b == [1, 2, 3]);
}

void applyUnary(string op, Tsource, Tdest)(Tsource source, Tdest dest)
    if(isInputRange!Tsource && isInputRange!Tdest)
{
    foreach(ref d; dest)
    {
        d = mixin(op ~ "source.front");
        source.popFront();
    }
}

unittest
{
    int[] a = [1, 2, 3];
    int[] b = [0, 0, 0];
    applyUnary!("-")(a, b);
    assert(b == [-1, -2, -3]);
}

void applyBinary(string op, Tsource1, Tsource2, Tdest)(Tsource1 source1,
                                                       Tsource2 source2,
                                                       Tdest dest)
    if(isInputRange!Tsource1 && isInputRange!Tsource2 && isInputRange!Tdest)
{
    foreach(ref d; dest)
    {
        d = mixin("source1.front" ~ op ~ "source2.front");
        source1.popFront();
        source2.popFront();
    }
}

unittest
{
    int[] a1 = [1, 2, 3];
    int[] a2 = [4, 5, 6];
    int[] b = [0, 0, 0];
    applyBinary!("+")(a1, a2, b);
    assert(b == [5, 7, 9]);
}
