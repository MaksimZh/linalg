// Written in the D programming language.

module linalg.storage.genericmd;

import std.algorithm;

import linalg.types;
import linalg.storage.container;
import linalg.storage.stride;

/* Generic multidimensional storage */
struct StorageGenericMD(T, StorageOrder storageOrder_, params...)
{
    public // Check and process parameters
    {
        static assert(params.length >= 1);

        enum size_t[] dimPattern = [params[0..$]];

        alias T ElementType; // Type of the array elements
        public enum uint rank = dimPattern.length; // Number of dimensions
        enum StorageOrder storageOrder = storageOrder_;

        /* Whether this is a static array with fixed dimensions and strides */
        enum bool isStatic = !canFind(dimPattern, dynamicSize);

        static if(isStatic)
            alias StaticArray!(ElementType, calcDenseContainerSize(dimPattern))
                ContainerType;
        else
            alias DynamicArray!ElementType ContainerType;
    }

    package ContainerType container;
}
