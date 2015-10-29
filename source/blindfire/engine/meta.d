module blindfire.engine.meta;

template isAttribute(alias curAttr, alias Attr) {
	enum isAttribute = is(typeof(curAttr) == typeof(Attr)) && curAttr == Attr;
} //isAttribute

template hasAttribute(T, alias Member, alias Attribute) {
	enum hasAttribute = hasAttribute_!(Member, Attribute, getAttributes!(T, Member));
} //hasAttribute

template hasAttribute_(alias Member, alias Attribute, Attributes...) {

	static if (Attributes.length > 0 && isAttribute!(Attribute, Attributes[0])) {

		enum hasAttribute_ = true;

	} else static if (Attributes.length > 0) {

		enum hasAttribute = hasAttribute_!(Member, Attribute, Attributes[1 .. $]);

	} else {

		enum hasAttribute_ = false;

	}

} //hasAttribute_

template getAttributes(T, alias Member) {
	enum getAttributes = __traits(getAttributes, __traits(getMember, T, Member));
} //getAttributes

template Identifier(alias Sym) {
	enum Identifier = __traits(identifier, Sym);
} //Identifier

template StringIdentifier(alias T, alias Member) {
	enum StringIdentifier = typeof(Symbol!(T, Member)).stringof;
} //StringIdentifier

template Symbol(alias T, alias Member) {
	enum Symbol = __traits(getMember, T, Member);
} //Symbol

template Symbol(T, alias Member) {
	enum Symbol = __traits(getMember, T, Member);
} //Symbol

template isPOD(T) {
	enum isPOD = __traits(isPOD, T);
} //isPOD

template hasMember(alias obj, string Member) {
	enum hasMember = __traits(hasMember, typeof(obj), Member);
} //hasMember

template hasMember(T, string Member) {
	enum hasMember = __traits(hasMember, T, Member);
} //hasMember