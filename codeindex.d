module codeindex;

import std.conv;

string codeIndexTuple(size_t rank)
{
    auto tmp = "size_t i" ~ to!string(rank - 1);
    if(rank == 1)
        return tmp;
    else
        return codeIndexTuple(rank - 1) ~ ", " ~ tmp;
}

string codeIndexOffset(string dimArray, size_t[] dim)
{
    auto tmp = "i" ~ to!string(dim.length - 1);
    if(dim.length == 1)
        return tmp;
    else
        return tmp ~ " + "
            ~ ((dim[$-2] == 0) ? dimArray ~ "[" ~ to!string(dim.length - 2) ~ "]" : to!string(dim[$-2]))
            ~ " * (" ~ codeIndexOffset(dimArray, dim[0..$-1]) ~ ")";
}

string codeIndexOverload(string elementTypeName, string dataName, string dimArray, size_t[] dim)
{
    return "ref " ~ elementTypeName ~ " opIndex(" ~ codeIndexTuple(dim.length) ~ ")\n"
        ~ "{ return " ~ dataName ~ "[" ~ codeIndexOffset(dimArray, dim) ~ "]; }";
}
