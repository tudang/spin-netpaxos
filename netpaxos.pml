#define ACCEPTORS 4
#define PROPOSERS 2
#define LEARNERS 2
#define MAJORITY (ACCEPTORS/2)+1
#define MAX (ACCEPTORS*PROPOSERS)
#define MAX2 (ACCEPTORS*LEARNERS)

chan p2m  = [PROPOSERS] of { byte, byte };
chan m2m  = [MAX] of { byte, byte };
chan m2l  = [MAX2] of { byte, byte, byte};
chan prepare = [MAX2] of { byte, byte };
chan promise = [MAX2] of { byte, byte, byte };
chan accept = [MAX2] of { byte, byte, byte };
chan accepted = [MAX2] of { byte, byte };

typedef array {
    byte aa[PROPOSERS]
};

array chosen[LEARNERS];
byte chosen_v[LEARNERS];

inline bprepare(rnd) {
    byte i;
    for(i:1.. ACCEPTORS) {
        prepare!i,rnd
    }
}

inline baccept(rnd, value) {
    byte i;
    for(i:1.. ACCEPTORS) {
        accept!i,rnd,value
    }
}

never {
p0: do
    :: true
    :: chosen_v[0] != 0 -> goto p1
    :: chosen_v[1] != 0 -> goto p2
    od
p1: do
    :: chosen_v[1] != 0 -> goto p3
    :: else
    od
p2: do
    :: chosen_v[0] != 0 -> goto p3
    :: else
    od
p3: do
    :: chosen_v[0] != chosen_v[1] -> break
    :: else
    od
end:
    skip
}


proctype Proposer(byte id, myval) {
    p2m!id,myval;
}

proctype Multiplexer() {
    byte i, j;
    byte p, val;
    byte vals[2];
    do
    ::  p2m?p,val -> vals[i] = val; i++;
    ::  i > 1 -> 
            for(j:1.. ACCEPTORS) {
                if
                :: (j%2) == 0 -> m2m!j,vals[1]
                :: else -> m2m!j,vals[0]
                fi
            }; 
            i = 0
    od
}

proctype Minion(byte id) {
    byte i;
    byte tmp_value, value;
    byte rnd, crnd;
    byte vrnd,vval; // store the latest value & associated round
end:
    do
    ::  m2m??eval(id),value -> 
            if
            :: vval == 0 -> vval = value
            :: else 
            fi;
            for(i:1.. LEARNERS) { m2l!i,id,value }  
    ::  prepare??eval(id),crnd ->
            if
            ::  crnd > rnd ->
                    rnd = crnd; 
                    vrnd = crnd;
                    promise!rnd,vrnd,vval;
            :: else fi
    ::  accept??eval(id),crnd,tmp_value ->
            if
            ::  crnd >= rnd ->
                    rnd = crnd;
                    vrnd = crnd;
                    vval = tmp_value
                    accepted!vrnd,vval
            ::  else fi;
    od
}

proctype Learner(byte id) {
    byte values[ACCEPTORS];
    byte value;
    byte minion;
    bool nsent = true; 
    byte count, vrnd, vval;
    byte hv, hr;
    byte counta;
    byte cur_rnd = id;
    byte prnd; 
    byte countdown;
    do
    ::  m2l??eval(id),minion,value ->
        if
        :: values[minion-1] == 0 ->
            values[minion-1] = value;
            chosen[id-1].aa[value-1]++
        :: else fi
    ::  chosen[id-1].aa[0] >= MAJORITY -> 
            chosen_v[id-1] = 1 ; break
    ::  chosen[id-1].aa[1] >= MAJORITY -> 
            chosen_v[id-1] = 2 ; break
    ::  chosen[id-1].aa[0] == 2 && chosen[id-1].aa[1] == 2 && nsent -> // Recovery Mode
        bprepare(cur_rnd);
        nsent = false
    ::  countdown <= 99 -> countdown++
    ::  countdown > 99 ->   
            prnd = cur_rnd;
            cur_rnd = cur_rnd + PROPOSERS;
            bprepare(cur_rnd); 
            countdown = 0
    ::  promise??eval(prnd),vrnd,vval -> skip
    ::  promise??eval(cur_rnd),vrnd,vval -> count++;
        if
        ::  vrnd >= hr -> hr = vrnd; hv = vval
        ::  else fi;
        if  
        ::  count == MAJORITY -> baccept(cur_rnd, hv); count = 0
        :: else fi;
    ::  accepted??eval(prnd),value ->  skip
    ::  accepted??eval(cur_rnd),value -> 
        if
        ::  value == hv -> counta++;
        :: else fi;
        if
        ::  counta >= MAJORITY -> chosen_v[id-1] = hv; break
        :: else fi
    od
}

// model reordering and loss of packet by having 
// a separated process to mess up the channel
proctype Evil() {
    byte id, value;
    do
    ::  atomic { nempty(m2m) ->  m2m?id,value; m2m!id,value }
//    ::  atomic { nempty(m2m) ->  m2m?id,value; skip }
    od
}

init {
    byte i;
    atomic {
        run Multiplexer();
        for(i:1.. PROPOSERS) {
            run Proposer(i,i);
        }
        for(i:1.. ACCEPTORS) {
            run Minion(i);
        }
        for(i:1.. LEARNERS) {
            run Learner(i);
        }
            
    }
}
