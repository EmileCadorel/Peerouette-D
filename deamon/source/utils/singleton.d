module utils.singleton;

/++
 + mixin permettant a une classe de devenir Singleton
 + Securise entre Thread
 + Example:
 + -----
 + class A {
 + 
 +   void print () {
 +       writeln ("Hello World");
 +   }
 +
 +   mixin Singleton!A;
 + }
 +
 + // ...
 +
 + A.instance.print ();
 + -----
 +/
mixin template Singleton () {

    alias T = typeof (this);
    
    private this () {}

    /++
     Returns: l'instance du singleton
     +/
    static ref T instance () {
	if (inst is null) {
	    inst = new T;
	}	
	return inst;
    }

private:

    __gshared static T inst = null;

}
