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
;; state-listはbuttonの8~71を0~63にスライドした順番。

(defmethod launchpad-lights-out
  (:init
    ()
    (setq state-list (make-list 64))
    (setq *random-state* (integer-vector (send (unix::now) :micro)
                                         (send (unix::now) :total-seconds)))
    (dotimes (idx (length state-list))
      (setf (elt state-list idx) (random 2)))
    (dotimes (idx (length state-list))
      (send self :state2led (+ idx 8))) ;; button8~71を初期化
    (ros::subscribe "/joy" sensor_msgs::Joy #'send self :joy-cb)
    )

  (:state2led ;; stateに応じて光らせる
    (b-id)
    (let ((state (elt state-list (- b-id 8)))
          (l-id (button2led-id b-id)))
      (case state
        (0 (pub-led l-id :off))
        (1 (pub-led l-id :orange))
        (t (pub-led l-id :red))))
    )

  ;; () 自分を含む周囲のbutton-idを返す

  (:joy-cb
    (msg)
    (let ((button-id (get-idx-from-value (send msg :buttons) 1)))
      (if (not (eq (button2led-id button-id) nil))
        (pub-led (button2led-id button-id) 1))
      ;; 対象ボタンを調べる
      ;; stateを反転させる
      ;; 光らせる
      ))
  )

;; atlasmarion/midi-gazebo-cotroller.lからコピペ
(defun get-idx-from-value (l value)
  (let ((answer-idx nil))
    (dotimes (idx (length l))
      (if (equal (elt l idx) value) (setq answer-idx idx)))
    answer-idx))

(unix::sleep 1) ;; midi_config_player待ち
(setq *launchpad-lights-out* (instance launchpad-lights-out :init))
(ros::spin)

