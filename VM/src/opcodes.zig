pub const OpCode = enum(u8) {
    //Math
    /// add two stack values, consuming both and putting the result on the stack
    Add,
    Sub,
    Mul,
    Div,

    //Stack
    /// push an immediate value onto the stack @TODO should switch to using some data thing (pointers maybe)
    Push,
    PushR,
    /// pop a byte off of the stack
    Pop,
    PopR,

    MoveD,
    MoveR,

    SetAt,

    Dup,
    DupAt,
    Swap,
    Rot,

    //Control Flow
    Equ,
    NEqu,
    LThn,
    GThn,
    Jump,
    CJump,
    Return,
    Quit,

    Amount,
};
