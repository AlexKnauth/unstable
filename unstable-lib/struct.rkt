#lang racket/base
;; owner: ryanc
(require (for-syntax racket/base
                     racket/struct-info)
         racket/struct)
(provide make
         struct->list
         (for-syntax get-struct-info))

;; get-struct-info : identifier stx -> struct-info-list
(define-for-syntax (get-struct-info id ctx)
  (define (bad-struct-name x)
    (raise-syntax-error #f "expected struct name" ctx x))
  (unless (identifier? id)
    (bad-struct-name id))
  (let ([value (syntax-local-value id (lambda () #f))])
    (unless (struct-info? value)
      (bad-struct-name id))
    (extract-struct-info value)))

;; (make struct-name field-expr ...)
;; Checks that correct number of fields given.
(define-syntax (make stx)
  (syntax-case stx ()
    [(make S expr ...)
     (let ()
       (define info (get-struct-info #'S stx))
       (define constructor (list-ref info 1))
       (define accessors (list-ref info 3))
       (unless (identifier? #'constructor)
         (raise-syntax-error #f "constructor not available for struct" stx #'S))
       (unless (andmap identifier? accessors)
         (raise-syntax-error #f "incomplete info for struct type" stx #'S))
       (let ([num-slots (length accessors)]
             [num-provided (length (syntax->list #'(expr ...)))])
         (unless (= num-provided num-slots)
           (raise-syntax-error
            #f
            (format "wrong number of arguments for struct ~s (expected ~s, got ~s)"
                    (syntax-e #'S)
                    num-slots
                    num-provided)
            stx)))
       (with-syntax ([constructor constructor])
         (syntax-property #'(constructor expr ...)
                          'disappeared-use
                          #'S)))]))
;; Eli: You give a good point for this, but I'd prefer if the optimizer would
;;   detect these, so you'd get the same warnings for constructors too when you
;;   use `-W warning'.  (And then, if you really want these things to be
;;   errors, then perhaps something at the racket level should make it throw
;;   errors instead of warnings.)
