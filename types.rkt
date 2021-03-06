#lang typed/racket

; TODO: If I ever remove the no-check from the other modules, remove the unsafe below.
(require typed/racket/unsafe)
(unsafe-provide (all-defined-out))

; Types should be in individual modules, but they aren't exported when using typed/racket/no-check
; So I put them here so I can freely no-check the other modules as needed.

(define-type VariableName Symbol)
(define-type VariableNames (Listof VariableName))

(define-type PyrSelfEvaluating (U Number String))
(define-type PyrVariable          Symbol)
(define-type PyrQuote      (List 'quote  Pyramid))
(define-type PyrAssign     (List 'set!   Target Pyramid))
(define-type PyrDefinition (List 'define (U VariableName VariableNames) Pyramid))
(define-type PyrIf         (List 'if     Pyramid Pyramid (U Nothing Pyramid)))
(define-type PyrLambda     (List 'lambda VariableNames Sequence))
(define-type PyrBegin      (List 'begin  (Listof Pyramid)))
(define-type PyrApplication (Pairof Pyramid Sequence))
(define-type PyrMacroApplication PyrApplication)
(define-type PyrMacro      (List 'defmacro (U VariableName VariableNames) (Listof Racket)))
(define-type PyrAsmPush    (List 'push (U 'shrink Fixnum) Fixnum))
(define-type PyrAsmOp      (List 'op Symbol))
(define-type PyrAsmByte    (List 'byte Fixnum))
(define-type PyrAsmLabel   (List 'label Symbol))
(define-type PyrAsm        (List 'asm (Listof (U PyrAsmPush PyrAsmOp PyrAsmByte PyrAsmLabel))))
(define-type Pyramid (U PyrSelfEvaluating
                        PyrVariable
                        PyrQuote
                        PyrAssign
                        PyrDefinition
                        PyrIf
                        PyrLambda
                        PyrBegin
                        PyrApplication
                        PyrMacroApplication
                        PyrMacro
                        PyrAsm
                        ))

(define-type Racket Any)
(define-type Value Any)
(define-type Sequence (Listof Pyramid))
(define-type Assertion Any)

(define-type Linkage (U 'next 'return LabelName))
(define-type Target RegisterName)
(define-type iseq-or-label (U label inst-seq))
(struct inst-seq ([ needs : RegisterNames ] [ modifies : RegisterNames ] [ statements : Instructions ]) #:transparent)

(define-type RegisterNames (Listof RegisterName))
; A DispatchObject is like an object in an OOP language.
; It's a closure that keeps internal state and has named methods that mutate it.
(define-type DispatchObject (-> Symbol Any * Any))
(define-type Stack DispatchObject)
(define-type Machine DispatchObject)
(define-type Register DispatchObject)

(define-type ControllerText (Listof Instruction))
(define-type RegisterName Symbol)
(define-type MachineOpResult Any)
(define-type MachineOp (-> Any))
(define-type LabelName Symbol)
(define-type LabelVal InstructionOps)
(define-type Label (Pairof LabelName LabelVal))
(define-type Labels (Listof Label))
(define-type PrimopExprHead (Pairof Symbol Symbol))
(define-type PrimopExprTail (Listof MExpr))
(define-type PrimopExpr (Pairof PrimopExprHead PrimopExprTail))
(define-type PrimopImpl (-> MachineOpResult * MachineOpResult))
(define-type Primop (List Symbol PrimopImpl))
(define-type Primops (Listof Primop))

(define-type StackInst (Pairof Symbol (Pairof RegisterName Any)))

(define-type RegisterValue Any)
(struct reg ([name : RegisterName]) #:transparent)
(struct const ([ value : RegisterValue ]) #:transparent)
(struct boxed-const ([ value : RegisterValue ]) #:transparent)
(struct label ([ name : Symbol ]) #:transparent)
(struct op ([ name : Symbol] [ args : MExprs ]) #:transparent)
(struct eth-stack () #:transparent)
(define stack (eth-stack))
(define stack? eth-stack?)
(define-type MExpr (U reg
                      const
                      boxed-const
                      label
                      op))
(define-type MExprs (Listof MExpr))

(define-type InstLabel         Symbol)
(struct assign ([ reg-name : RegisterName ] [ value-exp : MExpr ]) #:transparent)
(struct test ([ condition : MExpr ]) #:transparent)
(struct branch ([ dest : MExpr ]) #:transparent)
(struct goto ([ dest : MExpr ]) #:transparent)
(struct save ([ reg-name : RegisterName ]) #:transparent)
(struct restore ([ reg-name : RegisterName ]) #:transparent)
(struct perform ([ action : op ]) #:transparent)
(struct am-asm ([ insts : EthInstructions ]))
(define-type Instruction (U InstLabel
                            assign
                            test
                            branch
                            goto
                            save
                            restore
                            perform
                            PyrAsm
                            ))
(define-type Instructions (Listof Instruction))
(define-type InstructionOp (MPairof Instruction MachineOp))
(define-type InstructionOps (Listof InstructionOp))

(define-type Frame (Pairof (MListof VariableName) (MListof Value)))
(define-type Environment (MListof Frame))

(define-type Values (Listof Value))

(struct primitive ([ implementation : Procedure ]) #:transparent)
(struct procedure ([ parameters : VariableNames ] [ body : Sequence ] [ environment : Environment ]) #:transparent)

; Code generator
(struct eth-asm     ([ name : Symbol ]) #:transparent)
(struct eth-push    ([ size : (U 'shrink Byte) ] [ value : (U Integer Symbol label) ]) #:transparent)
(struct eth-unknown ([ byte : Fixnum ]) #:transparent)
(define-type EthInstruction     (U eth-asm eth-push eth-unknown label-definition))
(define-type EthInstructions    (Listof   EthInstruction))
(define-type (Generator  A)     (-> A     EthInstructions))
(define-type (Generator2 A B)   (-> A B   EthInstructions))
(define-type (Generator3 A B C) (-> A B C EthInstructions))

(struct opcode ([ byte : Byte ] [ name : Symbol ] [ num-reads : Fixnum ] [ num-writes : Fixnum ]) #:transparent)

(define-type EthWord Integer)

(define-type SymbolTable (Mutable-HashTable Symbol Integer))
(define-type ReverseSymbolTable (Mutable-HashTable Integer Symbol))
(define-type RelocationTable (Setof relocation))

(struct full-compile-result ([ bytecode : Bytes ] [ abstract-insts : Instructions ] [ eth-insts : EthInstructions ]) #:transparent)
(struct relocation ([ pos : Integer ] [ symbol : Symbol ]) #:transparent)
(struct patchpoint ([ symbol : Symbol ] [ initializer : EthInstructions ]) #:transparent)
(struct label-definition label ([ offset : Integer ] [ virtual : Boolean ]) #:transparent)

; A VM execution state

(define-type CodeHash EthWord)
(struct simulator ([ accounts : vm-world ] [ store : vm-store ] [ code-db : (HashTable CodeHash Bytes) ] ) #:transparent)

; Exception types
(struct exn:evm exn:fail ([ vm : vm-exec ]) #:transparent)
(struct exn:evm:return exn:evm ([ result : Bytes ]) #:transparent)
(struct exn:evm:misaligned-addr exn:evm ([ addr : EthWord ]) #:transparent)
(struct exn:evm:throw exn:evm ([ value : Bytes ]) #:transparent)
(struct exn:evm:did-not-halt exn:evm ([ max-iterations : Fixnum ]) #:transparent)
(struct exn:evm:stack-underflow exn:evm ([ ethi : EthInstruction ] [ num-elements : Fixnum ] [ stack : (Listof EthWord )]) #:transparent)
(struct exn:evm:misaligned-jump exn:evm ([ addr : EthWord ]))

(struct simulation-result ([ vm : vm-exec ] [ val : Bytes ] [ txn-receipt : vm-txn-receipt ]) #:transparent)
(define-type simulation-result-ex (U simulation-result exn:evm))
(define-type simulation-result-exs (Listof simulation-result-ex))

(define-type Address Integer) ; Ethereum addresses
(define-type StorageRoot EthWord)
(define-type LinkedOffset Integer)
(define-type UnlinkedOffset Integer)

(struct vm-account ([ nonce : Fixnum ] [ balance : EthWord ] [ storage-root : StorageRoot ] [ code-hash : CodeHash ]) #:mutable)
(struct vm-txn ([ nonce : Fixnum ]
                [ gas-price : Fixnum ]
                [ gas-limit : Fixnum ]
                [ to : Address ]
                [ value : Integer ]
                [ v : Fixnum ]
                [ r : Integer ]
                [ s : Integer ]
                [ data : Bytes ])
  #:transparent
  #:mutable
  )

(define-type Undefined Any)
(define-type vm-checkpoint Undefined)
(define-type vm-log Undefined)
(define-type vm-world (HashTable Address vm-account))

(struct vm-block ([ parent-hash : EthWord ]
                  [ ommers-hash : EthWord ]
                  [ beneficiary : EthWord ]
                  [ state-root : EthWord ]
                  [ transactions-root : EthWord ]
                  [ receipts-root : EthWord ]
                  [ logs-bloom : Undefined ]
                  [ difficulty : EthWord ]
                  [ number : Fixnum ]
                  [ gas-limit : Fixnum ]
                  [ gas-used : Fixnum ]
                  [ timestamp : Fixnum ]
                  [ extra-data : EthWord ]
                  [ mix-hash : EthWord ]
                  [ nonce : Integer ])
  #:transparent
  )

(struct vm-txn-receipt (; EVM spec
                        [ post-transaction : vm-world ]
                        [ cumulative-gas : Integer ]
                        [ log-bloom : Undefined ]
                        [ logs : (Listof vm-log) ]
                        ; Additional fields
                        [ contract-address : (U Null Address) ]
                        )
  #:transparent
  )
(struct vm-txn-substate ([ suicides : (Setof Address) ] [ log-series : (Setof vm-checkpoint) ] [ refund-balance : Fixnum ]) #:transparent)
(struct vm-exec-environment ([ contract : Address ] ; Account currently executing
                             [ origin : Address ]
                             [ gas-price : EthWord ]
                             [ input-data : Bytes ]
                             [ sender : Address ]
                             [ value : EthWord ]
                             [ bytecode : Bytes ]
                             [ header : vm-block ]
                             [ depth : Fixnum ]
                             [ writable? : Boolean ])
  #:transparent
  )
(struct vm-exec ([ step : Fixnum ]
                 [ pc : Fixnum ]
                 [ stack : (Listof EthWord) ]
                 [ memory : Bytes ]
                 [ gas : Fixnum ]
                 [ largest-accessed-memory : Fixnum ]
                 [ env : vm-exec-environment ]
                 [ sim : simulator ]
                 )
  #:mutable
  )

(define-type account-storage (HashTable EthWord EthWord)) ; An individual account's storage
(define-type world-storage (HashTable Address account-storage)) ; All accounts' storages
(define-type history-storage (HashTable StorageRoot world-storage)) ; All historical commit checkpoints

(struct vm-store ([ history : history-storage ]
                  [ world : world-storage ]
                  [ account : account-storage ])
  #:mutable)

(struct test-expectation ([ name : String ] [ expected : Any ] [ actual : (-> simulation-result-ex Any)]))
(struct test-txn ([ txn : (-> vm-txn) ] [ tests : (Listof test-expectation) ]) #:transparent #:mutable)
(struct test-case ([ name : String ] [ deploy-txn : test-txn ] [ txns : (Listof test-txn)]) #:transparent #:mutable)
(struct test-suite ([ name : String ] [ cases : (Listof test-case) ]) #:transparent)

; Constructors

(: make-symbol-table (-> SymbolTable))
(define (make-symbol-table) (make-hash))

(: make-reverse-symbol-table (-> ReverseSymbolTable))
(define (make-reverse-symbol-table) (make-hash))

(: make-relocation-table (-> RelocationTable))
(define (make-relocation-table) (set))
