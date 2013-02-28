// Written in the D programming language.

module linalg.matrix;

public import linalg.types;

import linalg.storage.dense2d;

struct Matrix(T, size_t nrows_, size_t ncols_,
              StorageOrder storageOrder_ = StorageOrder.rowMajor)
{
    alias StorageDense2D!(T, storageOrder_, nrows_, ncols_) StorageType;

    package StorageType storage;
}
