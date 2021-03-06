#lang typed/racket/no-check

(require racket/cmdline)
(require file/sha1)

(require "ast.rkt")
(require "codegen.rkt")
(require "serializer.rkt")
(require "compiler.rkt")
(require "types.rkt")
(require "io.rkt")
(require "disassembler.rkt")
(require "test.rkt")
(require "analysis.rkt")
(require "globals.rkt")
(require "parser.rkt")

(define file-to-compile
  (command-line
   #:program "pyramid"
   #:multi
   [("-v" "--verbose") "Compile with verbose messages. Used to debug the compiler."
                       (*verbosity* (+ 1 (*verbosity*)))]
   #:once-each
   [("-g")             "Compile with debug symbols"
                       (*use-debug-symbols?* #t)]
   [("-t")             "Run file as a test"
                       (*test?* #t)]
   [("-m")             "Minify the source"
                       (*minimize?* #t)]
   [("-l" "--link")
    val
    "Generate deployable Ethereum bytecode"
    (*link?* val)]
   #:args (filename) ; expect one command-line argument: <filename>
   filename))

(: verbose-output (-> Pyramid Void))
(define (verbose-output prog)
  (let* (;(the-global-environment (setup-environment))
         [ result           (full-compile prog) ]
         [ instructions     (first result) ]
         [ eth-instructions (second result) ]
         [ bs               (third result) ]
         )
    (begin
      (newline) (display prog)
      (newline) (display "Abstract Instructions:") (newline)
      (display-abstract-instructions (inst-seq-statements instructions))
      
      ; (newline) (display "EVM Instructions:") (newline) (display-all eth-instructions)
      ; (print-symbol-table (*symbol-table*))
      (print-relocations (*relocation-table*))
      (print-disassembly bs))))
  
(: standard-output (-> Pyramid Void))
(define (standard-output prog)
  (let ([bs (third (full-compile prog))])
    (write (bytes->hex-string bs))
    (newline)))

(define (main)
  (let ([ prog (read-file file-to-compile) ])
    (cond ((*test?*)  (assert-test file-to-compile prog))
          ((verbose? 1) (verbose-output prog))
          (else       (standard-output prog)))
    (when (verbose? VERBOSITY-MEDIUM)
      (display-macros))
    ))
(main)
