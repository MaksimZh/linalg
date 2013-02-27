// Written in the D programming language.

module linalg.storage.genericmd;

import linalg.container.dynamic;

/* Generic multidimensional storage */
struct StorageGenericMD(T)
{
    alias T ElementType;
    alias DynamicArray!ElementType ContainerType;

    package ContainerType container;
}
