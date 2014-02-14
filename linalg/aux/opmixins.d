// Written in the D programming language.

/**
 * Matrices.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2014, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.aux.opmixins;

mixin template InjectAssign(string checkTsource)
{
    ref auto opAssign(Tsource)(auto ref Tsource source) pure
        if(mixin(checkTsource))
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

mixin template InjectOpAssign(string checkTsource, Ops...)
{
    ref auto opOpAssign(string op, Tsource)(
        auto ref Tsource source) pure
        if(mixin(checkTsource) && isOpOf!(op, Ops))
    {
        linalg.operations.basic.zip!("a"~op~"b")(
            this.storage, source.storage, this.storage);
        return this;
    }
}

mixin template InjectOpAssignScalar(string checkTsource, Ops...)
{
    ref auto opOpAssign(string op, Tsource)(
        auto ref Tsource source) pure
        if(mixin(checkTsource) && isOpOf!(op, Ops))
    {
        linalg.operations.basic.map!((a, b) => mixin("a"~op~"b"))(
                this.storage, this.storage, source);
        return this;
    }
}

mixin template InjectOpAssignFwdBinary(string checkTsource, Ops...)
{
    ref auto opOpAssign(string op, Tsource)(
        auto ref Tsource source) pure
        if(mixin(checkTsource) && isOpOf!(op, Ops))
    {
        return (this = mixin("this"~op~"source"));
    }
}
