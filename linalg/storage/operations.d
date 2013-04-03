// Written in the D programming language.

module linalg.storage.operations;

debug import linalg.debugging;

import linalg.storage.regular1d;
import linalg.storage.regular2d;

void copy(Tsource, Tdest)(const ref Tsource source, ref Tdest dest) pure
    if((isStorageRegular2D!Tsource && isStorageRegular2D!Tdest)
        || (isStorageRegular1D!Tsource && isStorageRegular1D!Tdest))
    in
    {
        assert(dest.isCompatDim(source.dim));
    }
body
{
    debug(operations)
    {
        debugOP.writefln("operations.copy()");
        mixin(debugIndentScope);
        debugOP.writefln("from <%X>, %d",
                        source.container.ptr,
                        source.container.length);
        debugOP.writefln("to   <%X>, %d",
                        dest.container.ptr,
                        dest.container.length);
        debugOP.writeln("...");
        mixin(debugIndentScope);
    }
    auto isource = source.byElement;
    auto idest = dest.byElement;
    foreach(ref d; idest)
    {
        d = isource.front;
        isource.popFront();
    }
}

private template safeUnaryFun(alias fun)
{
    static if (is(typeof(fun) : string))
    {
        auto safeUnaryFun(ElementType)(auto ref const ElementType a) pure
        {
            mixin("return (" ~ fun ~ ");");
        }
    }
    else
    {
        alias fun safeUnaryFun;
    }
}

void map(alias fun, Tsource, Tdest)(
    const ref Tsource source, ref Tdest dest) pure
    if((isStorageRegular2D!Tsource && isStorageRegular2D!Tdest)
        || (isStorageRegular1D!Tsource && isStorageRegular1D!Tdest))
    in
    {
        assert(dest.isCompatDim(source.dim));
    }
body
{
    debug(operations)
    {
        debugOP.writefln("operations.map()");
        mixin(debugIndentScope);
        debugOP.writefln("from <%X>, %d",
                        source.container.ptr,
                        source.container.length);
        debugOP.writefln("to   <%X>, %d",
                        dest.container.ptr,
                        dest.container.length);
        debugOP.writeln("...");
        mixin(debugIndentScope);
    }
    alias safeUnaryFun!fun funToApply;
    auto isource = source.byElement;
    auto idest = dest.byElement;
    foreach(ref d; idest)
    {
        d = funToApply(isource.front);
        isource.popFront();
    }
}

private template safeBinaryFun(alias fun)
{
    static if (is(typeof(fun) : string))
    {
        auto safeBinaryFun(ElementTypeA, ElementTypeB)(
            auto ref const ElementTypeA a,
            auto ref const ElementTypeB b) pure
        {
            mixin("return (" ~ fun ~ ");");
        }
    }
    else
    {
        alias fun safeBinaryFun;
    }
}

void zip(alias fun, TsourceA, TsourceB, Tdest)(
    const ref TsourceA sourceA,
    const ref TsourceB sourceB,
    ref Tdest dest) pure
    if((isStorageRegular2D!TsourceA && isStorageRegular2D!TsourceB
        && isStorageRegular2D!Tdest)
       || (isStorageRegular1D!TsourceA && isStorageRegular1D!TsourceB
           && isStorageRegular1D!Tdest))
    in
    {
        assert(dest.isCompatDim(sourceA.dim));
        assert(sourceA.dim == sourceB.dim);
    }
body
{
    debug(operations)
    {
        debugOP.writefln("operations.zip()");
        mixin(debugIndentScope);
        debugOP.writefln("from <%X>, %d",
                        sourceA.container.ptr,
                        sourceA.container.length);
        debugOP.writefln("from <%X>, %d",
                        sourceB.container.ptr,
                        sourceB.container.length);
        debugOP.writefln("to   <%X>, %d",
                        dest.container.ptr,
                        dest.container.length);
        debugOP.writeln("...");
        mixin(debugIndentScope);
    }
    alias safeBinaryFun!fun funToApply;
    auto isourceA = sourceA.byElement;
    auto isourceB = sourceB.byElement;
    auto idest = dest.byElement;
    foreach(ref d; idest)
    {
        d = funToApply(isourceA.front, isourceB.front);
        isourceA.popFront();
        isourceB.popFront();
    }
}

auto mulAsMatrices(TsourceA, TsourceB)(
    const ref TsourceA sourceA,
    const ref TsourceB sourceB) pure
    if(isStorageRegular1D!TsourceA && isStorageRegular1D!TsourceB)
{
    debug(operations)
    {
        debugOP.writefln("operations.mulAsMatrices()");
        mixin(debugIndentScope);
        debugOP.writefln("from <%X>, %d",
                        sourceA.container.ptr,
                        sourceA.container.length);
        debugOP.writefln("from <%X>, %d",
                        sourceB.container.ptr,
                        sourceB.container.length);
        debugOP.writefln("to   return");
        debugOP.writeln("...");
        mixin(debugIndentScope);
    }

    auto isourceA = sourceA.byElement;
    auto isourceB = sourceB.byElement;
    auto result = isourceA.front * isourceB.front;
    isourceA.popFront();
    isourceB.popFront();
    while(!(isourceA.empty))
    {
        result += isourceA.front * isourceB.front;
        isourceA.popFront();
        isourceB.popFront();
    }
    return result;
}

void mulAsMatrices(TsourceA, TsourceB, Tdest)(
    const ref TsourceA sourceA,
    const ref TsourceB sourceB,
    ref Tdest dest) pure
    if(isStorageRegular2D!TsourceA && isStorageRegular1D!TsourceB
       && isStorageRegular1D!Tdest)
        in
        {
            assert(sourceA.ncols == sourceB.length);
        }
body
{
    debug(operations)
    {
        debugOP.writefln("operations.mulAsMatrices()");
        mixin(debugIndentScope);
        debugOP.writefln("from <%X>, %d",
                        sourceA.container.ptr,
                        sourceA.container.length);
        debugOP.writefln("from <%X>, %d",
                        sourceB.container.ptr,
                        sourceB.container.length);
        debugOP.writefln("to   <%X>, %d",
                        dest.container.ptr,
                        dest.container.length);
        debugOP.writeln("...");
        mixin(debugIndentScope);
    }

    auto idest = dest.byElement;
    foreach(rowA; sourceA.byRow)
    {
        idest.front = mulAsMatrices(rowA, sourceB);
        idest.popFront;
    }
}

void mulAsMatrices(TsourceA, TsourceB, Tdest)(
    const ref TsourceA sourceA,
    const ref TsourceB sourceB,
    ref Tdest dest) pure
    if(isStorageRegular1D!TsourceA && isStorageRegular2D!TsourceB
       && isStorageRegular1D!Tdest)
        in
        {
            assert(sourceA.length == sourceB.nrows);
        }
body
{
    debug(operations)
    {
        debugOP.writefln("operations.mulAsMatrices()");
        mixin(debugIndentScope);
        debugOP.writefln("from <%X>, %d",
                        sourceA.container.ptr,
                        sourceA.container.length);
        debugOP.writefln("from <%X>, %d",
                        sourceB.container.ptr,
                        sourceB.container.length);
        debugOP.writefln("to   <%X>, %d",
                        dest.container.ptr,
                        dest.container.length);
        debugOP.writeln("...");
        mixin(debugIndentScope);
    }

    auto idest = dest.byElement;
    foreach(colB; sourceB.byCol)
    {
        idest.front = mulAsMatrices(sourceA, colB);
        idest.popFront;
    }
}

void mulAsMatrices(TsourceA, TsourceB, Tdest)(
    const ref TsourceA sourceA,
    const ref TsourceB sourceB,
    ref Tdest dest) pure
    if(isStorageRegular2D!TsourceA && isStorageRegular2D!TsourceB
       && isStorageRegular2D!Tdest)
        in
        {
            assert(sourceA.ncols == sourceB.nrows);
        }
body
{
    debug(operations)
    {
        debugOP.writefln("operations.mulAsMatrices()");
        mixin(debugIndentScope);
        debugOP.writefln("from <%X>, %d",
                        sourceA.container.ptr,
                        sourceA.container.length);
        debugOP.writefln("from <%X>, %d",
                        sourceB.container.ptr,
                        sourceB.container.length);
        debugOP.writefln("to   <%X>, %d",
                        dest.container.ptr,
                        dest.container.length);
        debugOP.writeln("...");
        mixin(debugIndentScope);
    }

    auto idest = dest.byElement;
    foreach(rowA; sourceA.byRow)
        foreach(colB; sourceB.byCol)
        {
            idest.front = mulAsMatrices(rowA, colB);
            idest.popFront;
        }
}
