import std.stdio;

import linalg.matrix;

void main()
{
    auto a = Matrix!(int, 2, 2)([1, 2,
                                 3, 4]);
    auto b = Matrix!(int, 2, 2)([1, 2,
                                 3, 4]);
    b.array *= a;
    writeln(cast(int[][]) b);
}
