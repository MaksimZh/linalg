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

    static assert(isStorageOfRank!(StorageRegular1D!(int, 2), 1));
    static assert(!isStorageOfRank!(StorageRegular1D!(int, 2), 2));
    static assert(!isStorageOfRank!(StorageRegular2D!(
                                        int, defaultStorageOrder, 2, 3),
                                    1));
    static assert(isStorageOfRank!(StorageRegular2D!(
                                       int, defaultStorageOrder, 2, 3),
                                   2));
    static assert(!isStorageOfRank!(int, 1));
    static assert(!isStorageOfRank!(Slice, 2));
}
