// Written in the D programming language.

module linalg.storage.container;

template DynamicArray(T)
{
    alias T[] DynamicArray;
}

template StaticArray(T, size_t size)
{
    alias T[size] StaticArray;
}
