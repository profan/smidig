module smidig.ecs;

import std.algorithm : sort;
import std.traits : PointerTarget;
import std.typecons : Tuple;

import smidig.memory : IAllocator, make, dispose;

alias EntityID = uint;
alias ComponentName = string;
alias SystemType = int;

enum dependency = "dependency";

class EntityManager {

	import core.stdc.stdio : printf;
	import smidig.collections : Array, StaticArray;

	enum INITIAL_SYSTEMS = 10;
	enum MAX_SYSTEMS = 10;

	private {

		IAllocator allocator_;

		Array!IComponentManager cms_;
		Array!(Array!IComponentManager) systems_;

		EntityID current_id = 0;

	}

	this(IAllocator allocator) {

		this.allocator_ = allocator;
		this.cms_ = typeof(cms_)(allocator_, INITIAL_SYSTEMS);
		this.systems_ = typeof(systems_)(allocator_, MAX_SYSTEMS);
		this.systems_.length = MAX_SYSTEMS;

		foreach (ref a; systems_) {
			a = typeof(a)(allocator_, 8);
		}

	} //this

	~this() {

		foreach (man; cms_) {
			allocator_.dispose(man);
		}

	} //~this

	@property IAllocator allocator() {
		return allocator_;
	} //allocator

	S registerSystem(S, Args...)(Args args) {

		auto new_sys = allocator_.make!S(args);
		this.addSystem(new_sys);

		return new_sys;

	} //registerSystem

	private {

		void addSystem(S)(S cm) {

			static assert(S.identifier >= 0 && S.identifier < MAX_SYSTEMS);

			cm.setManager(this);
			uint id = S.identifier;
			systems_[id] ~= cm;
			sort(systems_[id][]);
			cms_ ~= cm;
			sort(cms_[]); //todo replace

		} //addSystem

		void addSystems(S...)(S systems_) {

			foreach (sys; systems_) {
				addSystem(sys);
			}

		} //addSystems

	}

	EntityID createEntity(EntityID entity) nothrow @nogc const {

		return entity;

	} //createEntity

	EntityID createEntity() nothrow @nogc {

		return current_id++;

	} //createEntity

	IComponentManager getManager(C = void)(ComponentName system = typeid(C).stringof) {

		foreach (id, man; cms_) {
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

		foreach (ref system; cms_) {
			system.clear();
		}

	} //clearSystems

	void deregister(S = void, C = void)(EntityID entity) {

		static if (!is(S == void)) {
			mixin("import " ~ moduleName!S ~ ";");
		}

		static if (is(C == void)) {

			foreach(ref sys; cms_) {
				sys.deregister(entity);
			}

		} else {

			getManager!(C).deregister(entity);

		}

		static if (is(S == void)) {

			foreach(ref arr; systems_) {
				foreach(ref sys; arr) {
					sys.deregister(entity);
				}
			}

		} else {

			foreach(ref sys; systems_[identifier!(S)]) {
				sys.deregister(entity);
			}

		}


	} //deregister

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

		foreach (ref sys; systems_[T.identifier]) {
			T s = cast(T)sys; //this is slightly evil
			s.update(args);
		}

	} //tick

} //EntityManager

interface IComponentManager {

	bool opEquals(ref const IComponentManager other) nothrow const @nogc;
	int opCmp(ref const IComponentManager other) nothrow const @nogc;
	void setManager(EntityManager em);

	@property IAllocator allocator();
	@property int priority() nothrow const @nogc;
	@property ComponentName name() nothrow const @nogc;
	bool register(EntityID entity);
	bool register(EntityID entity, void[] component); //TODO make nothrow?
	void deregister(EntityID entity);
	void* component(EntityID entity);
	void* allComponents() nothrow @nogc;
	void clear();

} //IComponentManager

interface ComponentSystem(uint Identifier, Args...) : IComponentManager {

	enum identifier = Identifier;
	void update(Args...)(Args args);

} //ComponentSystem

abstract class ComponentManager(System, T, int P = int.max) : System {

	import smidig.collections : HashMap;

	enum COMPONENT_NAME = typeid(T).stringof;
	enum INITIAL_SIZE = 32;
	enum PRIORITY = P;

	protected {

		EntityManager em;
		HashMap!(EntityID, T) components;

	}

	@property IAllocator allocator() { return em.allocator; }
	@property int priority() nothrow const @nogc { return PRIORITY; }
	@property ComponentName name() nothrow const @nogc { return COMPONENT_NAME; }

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

	void deregister(EntityID entity) {

		onDestroy(entity, entity in components);
		components.remove(entity);

	} //deregister

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

		import smidig.meta : hasAttribute;

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

		T c = T(); //FIXME this is positively horrifying, do something about this later.
		mixin setUpDependencies!(T, c, entity);
		linkUpDependencies();

		return c;

	} //constructComponent

	mixin template setUpDependencies(T, alias component, alias entity) {

		import std.traits : moduleName;

		void linkUpDependencies() {
			mixin fetchDependencies!(T, c, entity);
			mixin("import " ~ moduleName!T ~ ";"); //FIXME discard this later maybe, this system is kinda ew.
			mixin(fetchDependencies);
		}

	} //setUpDependencies

	void onInit(EntityID entity, T* component) {

		//is overriden in implementation, perform something on creation

	} //onInit

	void onDestroy(EntityID entity, T* component) {

		//is overriden in implementation, "destructor" for component essentially

	} //onDestroy

} //ComponentManager

version(unittest) {

	interface TestUpdateSystem : ComponentSystem!(0) {

		void update();

	}

	interface TestDrawSystem : ComponentSystem!(1) {

		void update(int value);

	}

	struct SomeComponent {
		int value;
	}

	class SomeManager : ComponentManager!(TestUpdateSystem, SomeComponent, 1) {

		void update() {
			foreach (ref comp; components) {
				comp.value += 1;
			}
		}

	}

	struct OtherComponent {
		@dependency SomeComponent* sc;
	}

	class OtherManager : ComponentManager!(TestUpdateSystem, OtherComponent, 2) {

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

	class DrawManager : ComponentManager!(TestDrawSystem, DrawComponent, 1) {

		void update(int value) {
			foreach (ref comp; components) {
				comp.value = value;
			}
		}

	}


}

version(unittest) {

	import std.string : format;

	void create_prerequisites(ref EntityManager em, ref EntityID entity) {

		import smidig.memory : theAllocator;

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
		em.tick!TestUpdateSystem(); //one iteration, value should now be 2
		auto val = em.getComponent!SomeComponent(entity).value;
		assert(val == 2, format("expected val of SomeComponent to be 2, order of updating is incorrect, was :%d", val));
	}
	{
		em.tick!TestDrawSystem(10); //one iteration, value should now be 10
		auto val = em.getComponent!DrawComponent(entity).value;
		assert(val == 10);
	}

}

unittest {

	import std.exception : assertNotThrown;

	mixin PreReq;
	create_prerequisites(em, entity);
	assertNotThrown!Exception(em.deregister(entity), "deregister should not throw an exception, likely out of bounds.");

}
