#!/afs/cats.ucsc.edu/courses/cse112-wm/usr/racket/bin/mzscheme -qr
;; $Id: sbi.scm,v 1.19 2020-01-14 16:58:47-08 - - $
;;
;; STUDENTS
;;    Timothy Wang tqwang
;;    Eric Mar emmar
;;
;; NAME
;;    sbi.scm - silly basic interpreter
;;
;; SYNOPSIS
;;    sbi.scm filename.sbir
;;
;; DESCRIPTION
;;    The file mentioned in argv[1] is read and assumed to be an SBIR
;;    program, which is the executed.  Currently it is only printed.
;;

;; Given - Defines consts for stdin, stdout, stderr, and arg-list
(define *stdin* (current-input-port))
(define *stdout* (current-output-port))
(define *stderr* (current-error-port))
(define *arg-list* (vector->list (current-command-line-arguments)))


;; Hash-table with all functions needed for lookup
(define *function-table* (make-hash))

(for-each
    (lambda (item)
        (hash-set! *function-table* (car item) (cadr item)))
    `(
           (+ , +)
           (- , -)
           (* , *)
           (/ , /)
           (^ , expt)
           (= , =)
           (< , <)
           (> , >)
           (!= , (lambda (x y) (not (equal? x y))))
           (>= , >=)
           (<= , <=)
           (abs , abs)
           (acos , acos)
           (asin , asin)
           (atan , atan)
           (ceiling , ceiling)
           (cos , cos)
           (exp , exp)
           (floor , floor)
           (log , log)
           (round , round)
           (sin , sin)
           (sqrt , sqrt)
           (tan , tan)
           (truncate , truncate)
      )
)

(define *variable-table* (make-hash))
;; Defines pi, e, non-numbers, and (?) end of file
(for-each
    (lambda (item) 
        (hash-set! *variable-table* (car item) (cadr item)))
    `(  
       (e , (exp 1.0))
       (pi , (acos -1.0))
       (i, (sqrt -1))
       (one, 1.0)
       (zero, 0.0)
       (eof , 0.0)
     )   
)

(define *array-table* (make-hash))

(define *label-table* (make-hash))

;; default error for evaluate-expression
(define NAN (\ 0.0 0.0))

;; evaluates the expression
(define (eval-expr expr)
    (cond 
          ;; if it's a num, return num
          ((number? expr) (+ expr 0.0))
          ;; if it's a symbol in variable-table, return that
          ((symbol? expr) (hash-ref *variable-table* expr NAN))
          ;; if it's a pair, do this
          ((pair? expr) 
              ;; sets func to first value in f and looks it up in functions
              (let ((func (hash-ref *function-table* (car expr) NAN))
                    (opnds (map eval-expr (cdr expr))))
                   ;; if func is null, error, else apply it
                   (if (null? func) NAN 
                       (apply func (map eval-expr opnds)))))
           ;; else error
           (else NAN)))

;; finds labels
(define (interpret-labels program)
        (when (not (null? program))
                (when (!= (length (car program)) 1)
                        (when (symbol? (cadr (car program)))
                                (hash-set! *label-table* (cadr(car program)) program)
                        )   
                )   
                (interpret-labels (cdr program) )
        )   
)

;; Interpets file line-by-line
(define (interpret-program program)
    (if (null? program)
        (exit 1)
        (   
                (let statement (car program)
                        (cond
                                ((equal? (length line) 2) (identify-keyword (cadr statement)))
                                ((equal? (length line) 3) (identify-keyword (caddr statement)))
                        )   
                )   
                (interpret-program (cdr program))   
        )
    )   
)

;; sorts statements to respective interpret functions
(define (identify-keyword statement)
        (cond 
                ((equal? (car statement) 'dim) (interpret-dim (cadr (cadr statement)) (caddr (cadr statement)) ))
                ((equal? (car statement) 'let) (interpret-let (cadr statement) (caddr statement) ))
                ((equal? (car statement) 'goto) (interpret-goto (cadr statement) ))
                ((equal? (car statement) 'if) (interpret-if (cadr statement) (caddr statement) ))
                ((equal? (car statement) 'print) (interpret-print (cdr statement) ))
                ((equal? (car statement) 'input) (interpret-input (car statement) ))
        )   
)

;; might still need some looking at, kind of confused
;; Creates a vector and puts it into array-table
(define (interpret-dim var expr)
        (if (symbol? var)
        (vector-set! *array-table* 
                var (make-vector (exact-round (eval-expr expr)) 0.0)))
        (exit 1)
)


;; let func
(define (interpret-let mem expr)
        (if ((symbol? mem) 
                (hash-set! *variable-table* 
                        name (exact-round (eval-expr expr))))
                ((if (and (vector? (cadr mem)) (> (vector-length (cadr mem)) ((caddr mem))) )
                        vector-set! *array-table* (cadr mem) (caddr mem) (eval-expr expr))
                        (exit 1)
                )   
        )   
)

;; Checks if label exists and is in label table, if it is, inteprets it
(define (interpret-goto label)
    ;; checks if label is null
    (if (null? label)
        (die '("Error: NULL label"))
        ;; checks if label is in table
        (if (hash-has-key? *label-table* label)
            (interpret-program (hash-ref *label-table* label)) 
            (die '("Error: Label not found in label table.")))))

;; Checks to see if the argslist expression is true, and goes to label if it is
(define (interpret-if args label)
    (when ((hash-ref *function-table* (car args))
      (eval-expr (cadr args)) (eval-expr (caddr args)))
        (interpret-goto label)))
    

;; <prints> is a list of printables 
(define (interpret-print prints )
    (if (null? prints)
            (printf "~n")
    (if (string? car prints)
            (display car prints)
        (display eval-expr (car prints)))
    (interpret-print (cdr prints)))) 

;; first argument of the <mems> list is the key//address (?) rest are the values to store
(define (interpret-input mems)
  if(null? mems)
      (exit 1)
  ()
)


;; Given - defines run file (?)
(define *run-file*
    (let-values
        (((dirpath basepath root?)
            (split-path (find-system-path 'run-file))))
        (path->string basepath))
)

;; Given - for when given an error, exits
(define (die list)
    (for-each (lambda (item) (display item *stderr*)) list)
    (newline *stderr*)
    (exit 1)
)

;; Given - exit out of program with error statement
(define (usage-exit)
    (die `("Usage: " ,*run-file* " filename"))
)

;; Given - reads list from input file
(define (readlist-from-inputfile filename)
    (let ((inputfile (open-input-file filename)))
         ;; If it's not the right type, errors, otherwise reads it
         (if (not (input-port? inputfile))
             (die `(,*run-file* ": " ,filename ": open failed"))
             (let ((program (read inputfile)))
                  (close-input-port inputfile)
                         program))))

;; Given - reads token from stdin?? not too sure
(define (dump-stdin)
    (let ((token (read)))
         (printf "token=~a~n" token)
         (when (not (eq? token eof)) (dump-stdin))))


;; Given - prints out what program is doing
(define (write-program-by-line filename program)
    (printf "==================================================~n")
    (printf "~a: ~a~n" *run-file* filename)
    (printf "==================================================~n")
    (printf "(~n")
    (for-each (lambda (line) (printf "~a~n" line)) program)
    (printf ")~n"))

;; Given - Main Function
(define (main arglist)
    ;; Check to make sure exactly 1 input, assumes sbir file
    (if (or (null? arglist) (not (null? (cdr arglist))))
        (usage-exit)
        (let* ((sbprogfile (car arglist))
               (program (readlist-from-inputfile sbprogfile)))
               (write-program-by-line sbprogfile program)
              (interpret-labels program)
              (interpret-program program)
              ))) 

;; Given - runs main
(main *arg-list*)