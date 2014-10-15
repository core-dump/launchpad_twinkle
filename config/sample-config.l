#!/user/bin/env roseus

;; 以下のようにキーコンフィグを書く。
;; 関数定義などはロード先でやる。

;; ボタン番号は次の通り
;;  ----------------------
;; |  1  2 ...  7  8      |
;; | -- -- --- -- --      |
;; | 11 12 ... 17 18 | 19 |
;; | 21 22 ... 27 28 | 29 |
;; |  .  . .    .  . | .  |
;; |  .  .   .  .  . | .  |
;; | 71 72 ... 77 78 | 79 |
;; | 81 82 ... 87 88 | 89 |
;;  ----------------------

;; 以下のようにボタン番号と実行したい式の対応を書く。
'(

  ;; ここで割り当てられたボタンはオレンジ色に光る。
  (led-funcs
   ;; このように書く。
   ( 8 (print "hello!"))
   ;; 複数行の式はprognでまとめる。
   (11 (progn (print "filst command")
              (print "seccond command")))
   ;; 逆に一つの式なら何でもいい。
   (13 (if (and (boundp '*state*) *state*)
           (progn (print "state: t")
                  (print "state: t!!!"))
         (print "state: nil")))
    )

  ;; ここで指定したボタンは割り当てがあっても光らない。
  (non-led-funcs
    (12 (print "this is non-LED-function."))
    )

  ;; 次のように書くとラジオボタン設定になり、
  ;; 組の中で最後に押されたボタンが赤、それ以外が緑に光る。
  ;; 起動時に赤くなるのは組の最初に書いたボタン。
  (radio-button-funcs
   ((22 (print "default"))
    (21 (print "not default 1"))
    (23 (print "not default 2")))

   ((31 (progn (setq *state* nil) (print "set *state* nil")))
    (32 (progn (setq *state* t) (print "set *state* t"))))

   )

  )
