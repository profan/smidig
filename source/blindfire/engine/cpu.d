module blindfire.engine.cpu;

struct CPU {

	import core.cpuid;
	import std.stdio : writefln;

	static void report_supported() {

		writefln("[CPU] Processor: %s", processor);
		writefln("[CPU] Cores: %d (%d logical threads)", coresPerCPU, threadsPerCPU);
		writefln("[CPU] Cache levels: %d", cacheLevels);
		writefln("[CPU] AVX2 supported: %s", avx2);
		writefln("[CPU] MMX supported: %s", mmx);
		writefln("[CPU] SSE: %s", sse);
		writefln("[CPU] SSE2: %s", sse2);
		writefln("[CPU] SSE3: %s", sse3);
		writefln("[CPU] SSE4.1: %s", sse41);
		writefln("[CPU] SSE4.2: %s", sse42);
		writefln("[CPU] SSE4a: %s", sse4a);
		writefln("[CPU] SSSE3: %s", ssse3);

	} //report_supported

} //CPU