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
    Stash,
    StoreNear,
    StoreFar,
    /// pop a byte off of the stack
    Pop,
    Nab,
    LoadNear,
    LoadFar,

    Set,
    SetNear,
    SetFar,

    Dup,
    DupNear,
    DupFar,
    Swap,
    Rot,

    //Control Flow
    Equ,
    NEqu,
    LThn,
    GThn,
    JumpNear,
    JumpFar,
    CJumpNear,
    CJumpFar,
    Return,

    //logic
    And,
    Or,
    XOr,
    ShiftL,
    ShiftR,

    Quit,

    Amount,
};
