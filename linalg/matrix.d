// Written in the D programming language.

module linalg.matrix;

import linalg.storage.genericmd;

struct Matrix(T)
{
    alias StorageGenericMD!T StorageType;

    package StorageType storage;
}
