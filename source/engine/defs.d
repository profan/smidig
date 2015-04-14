module blindfire.engine.defs;

import gfm.math : Vector, Matrix;

//Network related
alias ClientID = ubyte;
alias LocalEntityID = ulong;

//OpenGL maths related
alias Vec2i = Vector!(int, 2);
alias Vec2f = Vector!(float, 2);
alias Vec3f = Vector!(float, 3);
alias Vec4f = Vector!(float, 4);
alias Mat3f = Matrix!(float, 3, 3);
alias Mat4f = Matrix!(float, 4, 4);
