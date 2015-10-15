module blindfire.engine.ecs;

import std.algorithm : sort;
import std.traits : PointerTarget;
import std.typecons : Tuple;
import std.conv : to;

//FIXME defines in one place, consider if they should actually be there?
import blindfire.engine.defs : ClientID, LocalEntityID;
alias EntityID = LocalEntityID;

//things local to the module
alias ComponentName = string;
alias SystemType = int;

enum dependency = "dependency";

class EntityManager {

	import blindfire.engine.collections : Array, StaticArray;
	import blindfire.engine.memory : IAllocator;

	enum INITIAL_SYSTEMS = 10;
	enum MAX_SYSTEMS = 10;

	private {

		Array!IComponentManager cms;
		StaticArray!(IComponentManager[], MAX_SYSTEMS) systems;

		LocalEntityID current_id = 0;
		IAllocator allocator_;

	}

	this(IAllocator allocator) {
		this.allocator_ = allocator;
		this.cms = typeof(cms)(allocator, INITIAL_SYSTEMS);
	} //this

	void addSystem(S)(S cm) {

		static assert(S.identifier >= 0 && S.identifier < MAX_SYSTEMS);

		cm.setManager(this);
		uint id = S.identifier;
		systems[id] ~= cm;
		sort(systems[id]);
		cms ~= cm;
		sort(cms[]);

	} //addSystem

	void addSystems(S...)(S systems) {

		foreach (sys; systems) {
			addSystem(sys);
		}

	} //addSystems

	EntityID createEntity(EntityID entity) nothrow @nogc const {

		return entity;

	} //createEntity

	EntityID createEntity() nothrow @nogc {

		return current_id++;

	} //createEntity

	IComponentManager getManager(C = void)(ComponentName system = typeid(C).stringof) {

		foreach (id, man; cms) {
			if (man.name == system) return man;
		}

		return null;

	} //getManager

	C* getComponent(C)(EntityID entity) {

		return cast(C*)getManager!C().component(entity);

	} //getComponent

	C[EntityID] getAllComponents(C)() nothrow @nogc {

		return cast(C[EntityID])getManager!C().allComponents();

	} //getAllComponents

	void clearSystems() {

		foreach (ref system; cms) {
			system.clear();
		}

	} //clearSystems

	void unregister(S = void, C = void)(EntityID entity) {

		static if (!is(S == void)) {
			mixin("import " ~ moduleName!S ~ ";");
		}

		static if (is(C == void)) {

			foreach(sys; cms) {
				sys.unregister(entity);
			}

		} else {

			getManager!(C).unregister(entity);

		}

		static if (is(S == void)) {

			foreach(arr; systems) {
				foreach(sys; arr) {
					sys.unregister(entity);
				}
			}

		} else {

			foreach(sys; systems[identifier!(S)]) {
				sys.unregister(entity);
			}

		}


	} //unregister

	import core.stdc.stdio : printf;
	bool register(C)(EntityID entity) {

		IComponentManager em = getManager!C();

		if (em !is null) {
			return em.register(entity);
		} else {
			printf("[ECS] failed to register component!");
		}

		return false;

	} //register

	bool register(C)(EntityID entity, C component) {

		IComponentManager em = getManager!C();

		if (em !is null) {
			return em.register(entity, (cast(void*)&component)[0..component.sizeof]);
		}

		return false;

	} //register

	bool register(C, Args...)(EntityID id, Args args) {

		import std.algorithm : move;

		auto component = C(args);
		return register!C(id, move(component));

	} //register

	void register(CTypes...)(EntityID entity) {

		foreach (C; CTypes) {
			register!C(entity);
		}

	} //register

	void tick(T, Args...)(Args args) {

		foreach (sys; systems[T.identifier]) {
			T s = cast(T)sys; //this is slightly evil
			s.update(args);
		}

	} //tick

} //EntityManager

interface IComponentManager {

	bool opEquals(ref const IComponentManager other) nothrow const @nogc;
	int opCmp(ref const IComponentManager other) nothrow const @nogc;
	void setManager(EntityManager em);

	@property int priority() nothrow const @nogc;
	@property ComponentName name() nothrow const @nogc;
	bool register(EntityID entity);
	bool register(EntityID entity, void[] component); //TODO make nothrow?
	void unregister(EntityID entity);
	void* component(EntityID entity);
	void* allComponents() nothrow @nogc;
	void clear();

} //IComponentManager

interface ComponentSystem(uint Identifier, Args...) : IComponentManager {

	enum identifier = Identifier;
	void update(Args...)(Args args);

} //ComponentSystem

abstract class ComponentManager(System, T, int P = int.max) : System {

	enum INITIAL_SIZE = 32;

	import blindfire.engine.collections : HashMap;

	protected {
		EntityManager em;
		HashMap!(EntityID, T) components;
	}

	public {
		enum prio = P;
		enum cname = typeid(T).stringof;
	}

	@property int priority() nothrow const @nogc { return prio; }
	@property ComponentName name() nothrow const @nogc { return cname; }

	bool opEquals(ref const IComponentManager other) nothrow const @nogc {

		return name == other.name;

	} //opEquals

	int opCmp(ref const IComponentManager other) nothrow const @nogc {

		if (priority > other.priority) return 1;
		if (priority == other.priority) return 0;
		return -1;

	} //opCmp

	void setManager(EntityManager em) {

		this.components = typeof(components)(em.allocator_, INITIAL_SIZE);
		this.em = em;

	} //setManager

	bool register(EntityID entity) {

		import std.string : format;
		enum premade = format("%s component already exists for entity!", T.stringof);
		assert(entity !in components, premade);

		components[entity] = constructComponent(entity);
		onInit(entity, entity in components);
		return true;

	} //register(e)

	bool register(EntityID entity, void[] component) {

		import std.algorithm : move;
		components[entity] = T();

		T* c = cast(T*)component.ptr;
		mixin setUpDependencies!(T, c, entity);
		linkUpDependencies();

		move(*c, components[entity]);
		onInit(entity, entity in components);
		return true;

	} //register(e, component)

	void unregister(EntityID entity) {

		onDestroy(entity, entity in components);
		components.remove(entity);

	} //unregister

	void* component(EntityID entity) nothrow {

		return entity in components;

	} //component

	void* allComponents() nothrow @nogc {

		return &components;

	} //allComponents

	void clear() {

		components.clear();

	} //clear

	static template linkDependencies(T, alias comp, alias entsym, list...) {

		import blindfire.engine.meta : hasAttribute;

		static if (list.length > 0 && hasAttribute!(T, list[0], dependency)) {

			enum linkDependencies =
				__traits(identifier, comp) ~ "." ~ list[0] ~ " = em.getComponent!"
					~ __traits(identifier, PointerTarget!(typeof(__traits(getMember, T, list[0]))))
						~ "("~__traits(identifier, entsym)~");" ~ linkDependencies!(T, comp, entsym, list[1 .. $]);

		} else static if (list.length > 0 ) {

			enum linkDependencies = linkDependencies!(T, comp, entsym, list[1 .. $]);

		} else {

			enum linkDependencies = "";

		}

	} //linkDependencies

	template fetchDependencies(T, alias comp, alias entsym) {

		enum fetchDependencies = linkDependencies!(T, comp, entsym, __traits(allMembers, T));

	} //fetchDependencies

	/* called when you simply specify the type to build, no actual struct passed. */
	T constructComponent(EntityID entity) {
		T c = T(); //this is positively horrifying, do something about this later.
		mixin setUpDependencies!(T, c, entity);
		linkUpDependencies();
		return c;

	} //constructComponent

	mixin template setUpDependencies(T, alias component, alias entity) {

		import std.traits : moduleName;

		void linkUpDependencies() {
			mixin fetchDependencies!(T, c, entity);
			mixin("import " ~ moduleName!T ~ ";");
			mixin(fetchDependencies);
		}

	} //setUpDependencies

	void onInit(EntityID entity, T* component) {

		//when component created, do some stuff

	} //onInit

	void onDestroy(EntityID entity, T* component) {

		//do some finalization?

	} //onDestroy

} //ComponentManager

version(unittest) {

	interface UpdateSystem : ComponentSystem!(0) {

		void update();

	}

	interface DrawSystem : ComponentSystem!(1, int) {

		void update(int value);

	}

	struct SomeComponent {
		int value;
	}

	class SomeManager : ComponentManager!(UpdateSystem, SomeComponent, 1) {

		void update() {
			foreach (ref comp; components) {
				comp.value += 1;
			}
		}

	}

	struct OtherComponent {
		@dependency SomeComponent* sc;
	}

	class OtherManager : ComponentManager!(UpdateSystem, OtherComponent, 2) {

		void update() {
			foreach (ref comp; components) {
				if (comp.sc.value == 1) {
					comp.sc.value += 1;
				}
			}
		}

	}

	struct DrawComponent {
		int value;
	}

	class DrawManager : ComponentManager!(DrawSystem, DrawComponent, 1) {

		void update(int value) {
			foreach (ref comp; components) {
				comp.value = value;
			}
		}

	}


}

version(unittest) {

	void create_prerequisites(ref EntityManager em, ref EntityID entity) {

		import blindfire.engine.memory : theAllocator;

		//create manager, system
		em = new EntityManager(theAllocator);
		em.addSystems(
					  new SomeManager(),
					  new OtherManager(),
					  new DrawManager()
						  );

		//create entity and component, add to system
		entity = em.createEntity();
		em.register!(SomeComponent, OtherComponent, DrawComponent)(entity);

	}

	mixin template PreReq() {

		EntityID entity;
		EntityManager em;

	}

}

unittest {

	mixin PreReq;
	create_prerequisites(em, entity);
	assert(em.getComponent!SomeComponent(entity) !is null);
	em.getComponent!SomeComponent(entity).value = 0;

	{
		em.tick!(UpdateSystem)(); //one iteration, value should now be 2
		auto val = em.getComponent!SomeComponent(entity).value;
		assert(val == 2, format("expected val of SomeComponent to be 2, order of updating is incorrect, was :%d", val));
	}
	{
		em.tick!(DrawSystem)(10); //one iteration, value should now be 10
		auto val = em.getComponent!DrawComponent(entity).value;
		assert(val == 10);
	}

}

unittest {

	import std.exception : assertNotThrown;

	mixin PreReq;
	create_prerequisites(em, entity);
	assertNotThrown!Exception(em.unregister(entity), "unregister should not throw an exception, likely out of bounds.");

}