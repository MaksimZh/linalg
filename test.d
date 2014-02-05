import std.stdio;

import linalg.traits;
import linalg.types;
import linalg.storage.slice;
import linalg.storage.regular1d;
import linalg.storage.regular2d;

void main()
{
    static assert(isStorage!(StorageRegular1D!(int, 2)));
    static assert(isStorage!(StorageRegular2D!(int, defaultStorageOrder, 2, 3)));
    static assert(!isStorage!(int));
    static assert(!isStorage!(Slice));

    static assert(isStorageOfRank!(1, StorageRegular1D!(int, 2)));
    static assert(!isStorageOfRank!(2, StorageRegular1D!(int, 2)));
    static assert(!isStorageOfRank!(1, StorageRegular2D!(
                                        int, defaultStorageOrder, 2, 3)));
    static assert(isStorageOfRank!(2, StorageRegular2D!(
                                       int, defaultStorageOrder, 2, 3)));
    static assert(!isStorageOfRank!(1, int));
    static assert(!isStorageOfRank!(2, Slice));
}
