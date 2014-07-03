#!/usr/bin/env roseus

(ros::roseus "launchpad_reversi")
(require :launchpad-twinkle "package://launchpad_twinkle/euslisp/launchpad-twinkle.l")
(ros::load-ros-manifest "sensor_msgs")
(ros::advertise "/midi_joy/set_feedback" sensor_msgs::JoyFeedbackArray)

;; buttons
;; -------------------
;;  *  * ...  *  *
;; -- -- --- -- --
;;  8  9 ... 14 15 | 0
;; 16 17 ... 22 23 | 1
;;  .  . .    .  . | .
;;  .  .   .  .  . | .
;; 56 57 ... 62 63 | 6
;; 64 65 ... 70 71 | 7
;; -------------------

;; board(0~99, 外側に一回りボタンに対応しないマスがある)
;; -------------------
;;  *  * ...  *  *
;; -- -- --- -- --
;; 11 12 ... 17 18 | *
;; 21 22 ... 27 28 | *
;;  .  . .    .  . | .
;;  .  .   .  .  . | .
;; 71 72 ... 77 78 | *
;; 81 82 ... 87 88 | *
;; -------------------

;; LEDs
;; -------------------
;;  0  1 ...  6  7
;; -- -- --- -- --
;;  8  9 ... 14 15 | 16
;; 17 18 ... 23 24 | 25
;;  .  . .    .  . | .
;;  .  .   .  .  . | .
;; 62 63 ... 68 69 | 70
;; 71 72 ... 77 78 | 79
;; -------------------

(defclass launchpad-reversi
  :super object
  :slots (player player-lock pass-cnt prev-input-button state-list))
;; playerは1,2のどちらか。
;; state-listはboardのidで表す。
;; state-listには0（無所属）,1（1P）,2(2P)のどれかが入る。

(defmethod launchpad-reversi
  (:init
    ()
    (setq player 1)
    (setq player-lock nil)
    (setq pass-cnt (list 0 0))
    ;;(pub-led 0 :orange) ;; なんかここだと光らない
    (setq prev-input-button nil)
    (setq state-list (make-list 100 :initial-element 0))
    ;; 初期配置
    (setf (elt state-list 45) 1)
    (setf (elt state-list 54) 1)
    (setf (elt state-list 44) 2)
    (setf (elt state-list 55) 2)
    (dotimes (idx (length state-list))
      (send self :state2led idx))
    (pub-led 0 :orange) ;; ここだと光る
    (pub-led 16 :yellow)
    (ros::subscribe "/joy" sensor_msgs::Joy #'send self :joy-cb)
    )

  (:button2board-id
    (bt-id)
    (if (or (eq bt-id nil)
            (< bt-id 8)
            (> bt-id 71))
        nil
      (+ (* (/ bt-id 8) 10) (mod bt-id 8) 1)))

  (:board2led-id
    (bo-id)
    (if (or (eq bo-id nil)
            (< (mod bo-id 10) 1)
            (> (mod bo-id 10) 8)
            (< (/   bo-id 10) 1)
            (> (/   bo-id 10) 8))
        nil
      (+ (* (/ bo-id 10) 9) (mod bo-id 10) -2)))

  (:state2led ;; stateに応じて光らせる
    (bo-id)
    (if (eq bo-id nil) (return-from :state2led))
    (let ((state (elt state-list bo-id)) ;;はみ出したら死ぬ
          (l-id (send self :board2led-id bo-id)))
      (case state
        (0 (pub-led l-id :off))
        (1 (pub-led l-id :orange))
        (2 (pub-led l-id :green))
        (t (pub-led l-id :red))))
    )

  (:flip-list ;; 手に入る駒のリストを返す
   (bo-id)
   (let (ans-list)
     (setq ans-list (make-list 9)) ;; なぜかletの初期値では入らない
     (setf (elt ans-list 0) (list bo-id))
     (dotimes (i 8)
       (setf (elt ans-list (+ i 1)) (copy-object (send self :flip-list-oneline bo-id i))))
     ;; (print ans-list)
     ;; (setq ans-list (flatten ans-list)) ;; 平坦化
     ans-list)
   )

  (:flip-list-oneline ;; 8方向（右から反時計周り）のうち指定された方向の、反転する駒のリストを返す。
   (bo-id direction)
   (let ((ans-list (list nil))
         (target-id bo-id)
         x-step
         y-step)
     (case direction
           (0 (setq x-step  1) (setq y-step  0))
           (1 (setq x-step  1) (setq y-step  1))
           (2 (setq x-step  0) (setq y-step  1))
           (3 (setq x-step -1) (setq y-step  1))
           (4 (setq x-step -1) (setq y-step  0))
           (5 (setq x-step -1) (setq y-step -1))
           (6 (setq x-step  0) (setq y-step -1))
           (7 (setq x-step  1) (setq y-step -1))
           (t (return-from :flip-list-oneline)))
     (while t
       (setq target-id (+ target-id x-step (* y-step 10)))
       (case (elt state-list target-id)
         (0
          (setq ans-list (list nil))
          (return))
         ;;(player とすると入らなかった
         (t
          (if (eq (elt state-list target-id) player)
              (return))
          (setq ans-list (append ans-list (list target-id))))))
     ans-list)
   )

  ;; 途中で次の駒置けるか？ -> 置けなかった。spin-onceが来てないから。
  (:flip-led-animation ;; LEDによる反転アニメーション
   (flip-list)
   (let ((continue-flag t)
         (idx 0))
     (while continue-flag
       (setq continue-flag nil)
       ;; 一瞬赤くする
       (dolist (oneline-flip-list flip-list)
         (when (< idx (length oneline-flip-list))
             (pub-led (send self :board2led-id (elt oneline-flip-list idx)) :red)
             (if (< idx (1- (length oneline-flip-list)))
               (setq continue-flag t))))
       (unix::usleep (* 1000 100))
       ;; playerの色にする
       (dolist (oneline-flip-list flip-list)
         (when (< idx (length oneline-flip-list))
           (send self :state2led (elt oneline-flip-list idx))))
       (unix::usleep (* 1000 100))
       (setq idx (1+ idx))))
     ;; 念のため全マス更新
     (dotimes (idx (length state-list))
     (send self :state2led idx))
   )

  (:joy-cb
    (msg)
    (let ((button-id (get-idx-from-value (send msg :buttons) 1))
          (target-list))
      ;; 直前と同じボタン
      (if (eq button-id prev-input-button)
        (return-from :joy-cb))
      (setq prev-input-button button-id)
      ;; パスボタン
      (when (eq button-id 0)
        (if (send self :exist-placeable) (return-from :joy-cb)) ;; 必須でないパスは禁止
        (if (= player 1)
          (progn
            (setf (elt pass-cnt 0) (1+ (elt pass-cnt 0)))
            (setq player 2)
            (pub-led 0 :green)) ;; この処理メインループで1箇所にした方がいいね
          (progn
            (setf (elt pass-cnt 1) (1+ (elt pass-cnt 1)))
            (setq player 1)
            (pub-led 0 :orange)))
        (if (send self :exist-placeable) ;; これも
          (pub-led 16 :yellow)
          (pub-led 16 :red))
        (format t "pass: ~a~%" pass-cnt)
        (return-from :joy-cb))
      ;; 盤外のボタン
      (when (eq (send self :button2board-id button-id) nil)
        (setq prev-input-button nil)
        (return-from :joy-cb))
      ;; 置けない場所
      (when (not (send self :is-placeable (send self :button2board-id button-id)))
        (print "Implaceable!")
        (return-from :joy-cb))

      (setq target-list (send self :flip-list (send self :button2board-id button-id)))
      ;;(setq target-list (list (send self :button2board-id button-id)))
      (format t "player~a ~a~%" player target-list)
      ;; (format t "player~a was-placeable:~a~%" player (send self :is-placeable
      ;;                                           (send self :button2board-id button-id)))
      (dolist (target (flatten target-list))
        (setf (elt state-list target) player))
      (send self :flip-led-animation target-list)
      ;; (dotimes (idx (length state-list))
      ;;   (send self :state2led idx))
      (if (= player 1)
          (progn (setq player 2) (pub-led 0 :green))
        (progn (setq player 1) (pub-led 0 :orange)))
      (if (send self :exist-placeable)
        (pub-led 16 :yellow)
        (pub-led 16 :red))
      (format t "~%player~a exist-placeable: ~a~%" player (send self :exist-placeable))
      ))

  (:is-placeable ;; そのマスは置けるか？
   (bo-id)
   (let ((flat-flip-list)
         (ans nil))
     ;; ゲーム盤内？
     (if (or (< (mod bo-id 10) 1)
             (< (/   bo-id 10) 1)
             (> (mod bo-id 10) 8)
             (> (/   bo-id 10) 8))
      (return-from :is-placeable nil))
     ;; 駒は置かれていない？
     (if (not (= (elt state-list bo-id) 0))
         (return-from :is-placeable nil))
     ;; 反転できる駒はある？
     (setq flat-flip-list (flatten (send self :flip-list bo-id)))
     (dolist (flip-id flat-flip-list)
       (if (or (eq flip-id nil)
               (eq flip-id bo-id))
           nil
         (setq ans t)))
     ans)
   )

  (:exist-placeable ;; 置けるマスがあるか？
   ()
   (let ((ans nil))
     (dotimes (i (length state-list))
       (if (send self :is-placeable i)
         (setq ans t)))
     ans)
   )

  (:finish-judge
   ()
   ;;(send self :wait-and-lock player-lock)
   (let ((player-bak player)
         (is-finished t))
     (setq player 1)
     (if (send self :exist-placeable) (setq is-finished nil))
     (setq player 2)
     (if (send self :exist-placeable) (setq is-finished nil))
     (setq player player-bak)
     ;;(setq player-lock nil)
     is-finished)
   )

  (:wait-and-lock
   (lock)
   (while t
     (when (not lock)
       (setq lock t)
       (return-from :wait-and-lock)))
   )

  (:count-stone
   ()
   (let ((pl1 0)
         (pl2 0))
     (dotimes (i (length state-list))
       (case (elt state-list i)
         (1 (setq pl1 (1+ pl1)))
         (2 (setq pl2 (1+ pl2)))))
     (list pl1 pl2))
   )

  (:show-result
   ()
   (pub-led 0 :red)
   (let (stone-cnt winner)
     (setq stone-cnt (send self :count-stone))
     (if (> (elt stone-cnt 0) (elt stone-cnt 1))
       (setq winner 1)
       (if (< (elt stone-cnt 0) (elt stone-cnt 1))
         (setq winner 2)
         (setq winner nil)))
     (if winner
       (format t "~%~%*** Game over ***~%~%Player~a wins!~%~%" winner)
       (format t "~%~%*** Game over ***~%~%Draw game...~%~%"))
     (format t "* * *~%~%Player1: ~a stones, ~a passes~%Player2: ~a stones, ~a passes~%~%"
             (elt stone-cnt 0)
             (elt pass-cnt 0)
             (elt stone-cnt 1)
             (elt pass-cnt 1))
     (format t "* * *~%~%Thank you for playing!~%~%* * *~%~%"))
   )

  )

;; atlasmarion/midi-gazebo-cotroller.lからコピペ
(defun get-idx-from-value (l value)
  (let ((answer-idx nil))
    (dotimes (idx (length l))
      (if (equal (elt l idx) value) (setq answer-idx idx)))
    answer-idx))

(unix::sleep 1) ;; midi_config_player待ち
(setq *launchpad-reversi* (instance launchpad-reversi :init))

;; やたらファンが回る(ros::rate)とか？
;; 最初にボタンを押したとき、/midi_joy/set_feedbackが1000hz以上出てるのが気になる。
(ros::rate 30)
(while (ros::ok)
  (ros::spin-once)
  (when (send *launchpad-reversi* :finish-judge)
    (send *launchpad-reversi* :show-result)
    (exit))
  (ros::sleep))