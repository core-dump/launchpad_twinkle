#!/usr/bin/env roseus

(ros::roseus "launchpad_lights_out")
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

(defclass launchpad-lights-out
  :super object
  :slots (state-list))
;; state-listはbutton-idxに合わせる。

(defmethod launchpad-lights-out
  (:init
    (setq state-list (make-list 64))
    (dotimes (idx (length state-list))
      (setf (elt state-list idx) (random 2)))
    ;; 光らせる
    ;; コールバックの設定
    )

  ;; () stateに応じて光らせる

  ;; () 自分を含む周囲のbutton-idを返す

  (:joy-cb
    (msg)
    ;; 対象ボタンを調べる
    ;; stateを反転させる
    ;; 光らせる
    )
  )
