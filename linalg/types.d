// Written in the D programming language.

module linalg.types;

import std.traits;

/** Value to denote not fixed dimension of the array */
enum size_t dynamicSize = 0;

/** Order of the elements in the container */
enum StorageOrder
{
    rowMajor, /// 000, 001, 002, ..., 010, 011, ...
    colMajor  /// 000, 100, 200, ..., 010, 110, ...
}

enum StorageOrder defaultStorageOrder = StorageOrder.rowMajor;

template TypeOfOp(Tlhs, string op, Trhs)
{
    alias ReturnType!((Tlhs lhs, Trhs rhs) => mixin("lhs"~op~"rhs"))
        TypeOfOp;
}
