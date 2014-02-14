// Written in the D programming language.

/**
 * Matrices.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2014, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.aux.opmixins;

mixin template InjectAssign(alias checkSourceType)
{
    ref auto opAssign(Tsource)(auto ref Tsource source) pure
        if(checkSourceType!Tsource)
    {
        static if(memoryManag == MemoryManag.dynamic)
            this.storage = typeof(this.storage)(source.storage);
        else
            copy(source.storage, this.storage);
        return this;
    }
}

template isOpOf(string op, Ops...)
{
    static if(Ops.length == 1)
        enum bool isOpOf = (op == Ops[0]);
    else
        enum bool isOpOf = (op == Ops[0]) || isOpOf!(op, Ops[1..$]);
}

unittest
{
    static assert(isOpOf!("+", "+"));
    static assert(isOpOf!("+", "+", "-"));
    static assert(!isOpOf!("*", "+", "-"));
}

mixin template InjectOpAssign(alias checkSourceType, Ops...)
{
    ref auto opOpAssign(string op, Tsource)(
        auto ref Tsource source) pure
        if(checkSourceType!Tsource && isOpOf!(op, Ops))
    {
        linalg.operations.basic.zip!("a"~op~"b")(
            this.storage, source.storage, this.storage);
        return this;
    }
}
