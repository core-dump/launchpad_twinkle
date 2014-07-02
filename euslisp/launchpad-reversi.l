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
  :slots (player prev-input-button state-list))
;; playerは1,2のどちらか
;; state-listはbuttonの8~71を0~63にスライドした順番。
;; state-listには0（無所属）,1（1P）,2(2P)のどれかが入る。

(defmethod launchpad-reversi
  (:init
    ()
    (setq player 1)
    (pub-led 0 :orange)
    (setq prev-input-button nil)
    (setq state-list (make-list 64 :initial-element 0))
    (dotimes (idx (length state-list))
      (send self :state2led (+ idx 8))) ;; button8~71を初期化
    (ros::subscribe "/joy" sensor_msgs::Joy #'send self :joy-cb)
    )

  (:state2led ;; stateに応じて光らせる
    (b-id)
    (let ((state (elt state-list (- b-id 8))) ;;はみ出したら死ぬ
          (l-id (button2led-id b-id)))
      (case state
        (0 (pub-led l-id :off))
        (1 (pub-led l-id :orange))
        (2 (pub-led l-id :green))
        (t (pub-led l-id :red))))
    )

  (:strike-list ;; 手に入る駒のリストを返す（未実装）
   (b-id)
   (list b-id))

  (:joy-cb
    (msg)
    (let ((button-id (get-idx-from-value (send msg :buttons) 1))
          (target-list))
      (when (or (eq button-id nil)
                (< button-id 8))
        (setq prev-input-button nil)
        (return-from :joy-cb))
      ;; 押しっぱなしには反応しない
      (if (eq button-id prev-input-button)
        (return-from :joy-cb))
      (setq prev-input-button button-id)
      (setq target-list (send self :strike-list button-id))
      (format t "~a ~a~%" player target-list)
      (dolist (target target-list)
        (setf (elt state-list (- target 8)) player))
      (dotimes (idx (length state-list))
        (send self :state2led (+ idx 8)))
      (if (= player 1)
          (progn (setq player 2) (pub-led 0 :green))
        (progn (setq player 1) (pub-led 0 :orange)))
      ))

  (:finish-judge ())
  )

;; atlasmarion/midi-gazebo-cotroller.lからコピペ
(defun get-idx-from-value (l value)
  (let ((answer-idx nil))
    (dotimes (idx (length l))
      (if (equal (elt l idx) value) (setq answer-idx idx)))
    answer-idx))

(unix::sleep 1) ;; midi_config_player待ち
(setq *launchpad-reversi* (instance launchpad-reversi :init))

(while t
  (ros::spin-once)
  (if (send *launchpad-reversi* :finish-judge)
    (return)))
