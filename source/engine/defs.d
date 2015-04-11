module blindfire.defs;

import gfm.math : Vector, Matrix;

//Networking Identifiers
alias ClientID = ubyte;

//ECS ID
alias LocalEntityID = ulong;

//OpenGL maths related
alias Vec2f = Vector!(float, 2);
alias Vec3f = Vector!(float, 3);
alias Vec4f = Vector!(float, 4);
alias Mat3f = Matrix!(float, 3, 3);
alias Mat4f = Matrix!(float, 4, 4);
