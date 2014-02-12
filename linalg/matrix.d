module test;

import std.traits;

template TypeOfOp(Tlhs, string op, Trhs)
{
    alias ReturnType!((Tlhs lhs, Trhs rhs) => mixin("lhs"~op~"rhs"))
        TypeOfOp;
}

void copy(Tsrc, Tdest)(Tsrc src, Tdest dest)
{
    alias TypeOfOp!(Tdest.E, "=", Tsrc.E) Tresult;
}

struct BasicMatrix(T)
{
    alias T E;
    auto opAssign(S)(S s) { return this; }
    void foo() { copy(this, this); }
}

struct Foo { BasicMatrix!(int) coeffs; }

alias BasicMatrix!(Foo) XXX;
