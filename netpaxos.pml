#define ACCEPTORS 4
#define PROPOSERS 2
#define LEARNERS 2
#define MAJORITY (ACCEPTORS/2)+1
#define MAX (ACCEPTORS*PROPOSERS)
#define MAX2 (ACCEPTORS*LEARNERS)
#define p (chosen_v[0] != 0)
#define q (chosen_v[0] != 0)

chan m2m  = [MAX] of { byte, byte };
chan m2l  = [MAX2] of { byte, byte, byte};

typedef array {
    byte aa[PROPOSERS]
};

array chosen[LEARNERS];
byte chosen_v[LEARNERS];
/*
never {
p0: do
    :: true
    :: chosen_v[0] != 0 -> goto p1
    :: chosen_v[1] != 0 -> goto p2
    od
p1: do
    :: chosen_v[1] != 0 -> goto accept
    :: else
    od
p2: do
    :: chosen_v[0] != 0 -> goto accept
    :: else
    od
accept: do
    :: chosen_v[0] != chosen_v[1] -> break
    :: else
    od
end:
    skip
}
*/

proctype Proposer(byte id, myval) {
    byte i;
    for(i:1.. ACCEPTORS) {
    m2m!i,myval;
    }
}


proctype Minion(byte id) {
    byte i;
    byte value;
    byte first; // store the value that arrives first
    byte rnd;
    do
    :: m2m??eval(id),value -> 
        if
        :: first == 0 -> first = value
        :: else 
        fi;
        for(i:1.. LEARNERS) { m2l!i,id,value }  
    od
}

proctype Learner(byte id) {
    byte values[ACCEPTORS];
    byte value;
    byte minion;
    do
    ::m2l??eval(id),minion,value ->
        if
        :: values[minion-1] == 0 ->
            values[minion-1] = value;
            chosen[id-1].aa[value-1]++
        :: else fi
    :: chosen[id-1].aa[0] >= MAJORITY -> 
            chosen_v[id-1] = 1 ; break
    :: chosen[id-1].aa[1] >= MAJORITY -> 
            chosen_v[id-1] = 2 ; break
    :: chosen[id-1].aa[0] == 2 && chosen[id-1].aa[1] == 2 -> // Recovery Mode
    od
}

// model reordering and loss of packet by having 
// a separated process to mess up the channel
proctype Evil() {
    byte id,minion,value;
    do
    ::  atomic { len(m2l) > ACCEPTORS ->  m2l?id,minion,value; m2l!id,minion,value }
    ::  atomic { len(m2l) > ACCEPTORS ->  m2l?id,minion,value ; skip }
    od
}

init {
    byte i;
    atomic {
        for(i:1.. PROPOSERS) {
            run Proposer(i,i);
        }
        for(i:1.. ACCEPTORS) {
            run Minion(i);
        }
        for(i:1.. LEARNERS) {
            run Learner(i);
        }
        run Evil();
    }
}
