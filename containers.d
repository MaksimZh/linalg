// Written in the D programming language.

/** Arrays and matrices.

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module containers;

import stride;

/** Value to denote not fixed dimension of the array */
enum size_t dynamicSize = 0;

/** Order of the elements in the container */
enum StorageOrder
{
    rowMajor,   /// [0][0][0], ..., [0][0][N], [0][1][0], ...
    columnMajor /// [0][0][0], ..., [N][0][0], [0][1][0], ...
}

/** Type of the storage */
enum StorageType
{
    fixed, /// static array
    dynamic, /// dynamic array
    resizeable /// dynamic array with memory management
}

/* Storage and dimension management for arrays and matrices */
mixin template storage(ElementType, alias dimPattern,
                       StorageType storageType,
                       StorageOrder storageOrder)
{
    static assert(is(typeof(dimPattern[0]) : size_t));

    public enum uint rank = dimPattern.length; // Number of dimensions

    /* dimensions, strides and data */
    private static if(storageType == StorageType.fixed)
    {
        enum size_t[] _dim = dimPattern;
        enum size_t[] _stride =
            calcDenseStrides(_dim, storageOrder == StorageOrder.columnMajor);
        ElementType[calcDenseContainerSize(_dim)] _data;
    }
    else
    {
        size_t[rank] _dim = dimPattern;
        size_t[rank] _stride;
        ElementType[] _data;
    }

    /* Leading dimension */
    static if(dimPattern[0] != dynamicSize)
        public enum size_t length = dimPattern[0];
    else
        public size_t length() { return _dim[0]; }

    /* Full dimensions array */
    static if(storageType == StorageType.fixed)
        public enum size_t[rank] dimensions = _dim;
    else
        public @property size_t[rank] dimensions() pure const { return _dim; }


    /* Change dimensions */
    static if(storageType == StorageType.resizeable)
    {
        /* Recalculate strides and reallocate container for current dimensions
         */
        private void _resize() pure
        {
            _stride = calcDenseStrides(_dim, isTransposed);
            _container.length = calcDenseContainerSize(_dim);
        }

        /* Change dynamic array dimensions.
           Dimensions passed to the function must be compatible.
         */
        void setAllDimensions(in size_t[] dim) pure
            in
            {
                assert(dim.length == rank);
                assert(isCompatibleDimensions(dim));
            }
        body
        {
            _dim = dim;
            _resize();
        }

        /* Change dynamic array dimensions
           Number of parameters must coincide with number of dynamic dimensions
         */
        void setDimensions(in size_t[] dim...) pure
            in
            {
                assert(dim.length == rankDynamic);
            }
        body
        {
            uint i = 0;
            foreach(d; dim)
            {
                while(dimPattern[i] != dynamicSize) ++i;
                _dim[i] = d;
                ++i;
            }
            _resize();
        }
    }
}
