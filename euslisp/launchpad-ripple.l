#!/usr/bin/env roseus

(ros::roseus "launchpad_ripple")
(require :launchpad-twinkle "package://launchpad_twinkle/euslisp/launchpad-twinkle.l")
(ros::load-ros-manifest "sensor_msgs")
(ros::advertise "/midi_joy/set_feedback" sensor_msgs::JoyFeedbackArray)

;; axes
;; -------------------
;;  0  1 ...  6  7
;; -- -- --- -- --
;; 16 17 ... 22 23 | 8
;; 24 25 ... 30 31 | 9
;;  .  . .    .  . | .
;;  .  .   .  .  . | .
;; 64 65 ... 70 71 | 14
;; 72 73 ... 78 79 | 15
;; -------------------

;; board, LEDs
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

(defclass launchpad-ripple
  :super object
  :slots (prev-input-button state-list ripple-list))
;; state-listはboardのidで表す。

(defmethod launchpad-ripple
  (:init
    ()
    (setq prev-input-button nil)
    (setq state-list (make-list 80 :initial-element 0))
    (dotimes (idx (length state-list))
      (send self :state2led idx))
    (setq ripple-list nil)
    (setq *random-state* (integer-vector (send (unix::now) :micro)
                                         (send (unix::now) :total-seconds)))
    (ros::subscribe "/joy" sensor_msgs::Joy #'send self :joy-cb)
    )

  (:button2board-id
    (bt-id)
    (let (ans)
      (cond ((eq bt-id nil)
             (setq ans nil))
            ((and (>= bt-id  0) (<= bt-id  7))
             (setq ans bt-id))
            ((and (>= bt-id  8) (<= bt-id 15))
             (setq ans (+ (* (- bt-id 8) 9) 16)))
            ((and (>= bt-id 16) (<= bt-id 79))
             (setq ans (+ (* (/ bt-id 8) 9) (mod bt-id 8) -10)))
            (t
              (setq ans nil))))
    )

  (:board2led-id (bo-id) bo-id)

  (:state2led ;; stateに応じて光らせる
    (bo-id)
    (if (eq bo-id nil) (return-from :state2led))
    (let ((state (elt state-list bo-id)) ;;はみ出したら死ぬ
          (l-id (send self :board2led-id bo-id)))
      (case state
        (0 (pub-led l-id :off))
        (1 (pub-led l-id :red))
        (2 (pub-led l-id :orange))
        (3 (pub-led l-id :yellow))
        (4 (pub-led l-id :green))))
    )

  (:reset-state-list
    ()
    (dotimes (i (length state-list))
      (setelt state-list i 0))
    )

  (:statelist2led
   ()
   (dotimes (i (length state-list))
     (send self :state2led i))
   )

  (:change-state-all
   ()
   (send-all ripple-list :change-state state-list)
   )

  (:inc-step-all
   ()
   (send-all ripple-list :inc-step)
   )

  (:joy-cb
    (msg)
    ;; (setq tmp msg)
    (let ((button-id (get-idx-from-value (send msg :axes) 1.0))
          (target-id))
      ;; 直前と同じボタン
      (if (eq button-id prev-input-button)
        (return-from :joy-cb))
      (setq prev-input-button button-id)
      ;; ボタン離したとき
      (if (eq button-id nil)
          (return-from :joy-cb))

      (setq target-id (send self :button2board-id button-id))
      (setq ripple-list
        (append ripple-list
          (list (instance ripple :init target-id 0.1 (1+ (random 4))))))
      (send self :clean-ripple-list)
      ;; (print ripple-list)

      ;; (format t "(~a, ~a)~%" button-id target-id)
      ;;(send self :change-state target-id)
      ;;(dotimes (idx (length state-list))
      ;;  (send self :state2led idx))
      ))

  (:clean-ripple-list
   ()
   (dolist (ripple ripple-list)
      ;; (format t "~a ~a~%" ripple (send ripple :circle-list))
     (if (not (send ripple :circle-list))
         ;; (delete)は1番目の要素が消えなかった。
         (setq ripple-list (remove ripple ripple-list :count 1))))
   )

  )

(defclass ripple
  :super object
  :slots (center speed color step))

(defmethod ripple
  (:init
   (i-center i-speed i-color) ;; optional
   (setq center i-center)
   (setq speed i-speed)
   (setq color i-color)
   (setq step 0))

  (:circle-list ;; この中で枠外は除去
   ()
   (let (dist ans-list target-id)
     (setq dist (round (* speed step)))

     (do ((dx (- dist) (1+ dx))) ((> dx dist))
         ;;(print target-id)
       (setq target-id (shift-board-id center dx (- dist)))
       (if (and target-id
                (>= target-id 8)
                (<= target-id 78)
                (/= (mod target-id 9) 7))
       (setq ans-list (append ans-list (list target-id))))

       (setq target-id (shift-board-id center dx dist))
       (if (and target-id
                (>= target-id 8)
                (<= target-id 78)
                (/= (mod target-id 9) 7))
       (setq ans-list (append ans-list (list target-id)))))

     (do ((dy (- dist) (1+ dy))) ((> dy dist))
       (setq target-id (shift-board-id center (- dist) dy))
       (if (and target-id
                (>= target-id 8)
                (<= target-id 78)
                (/= (mod target-id 9) 7))
       (setq ans-list (append ans-list (list target-id))))

       (setq target-id (shift-board-id center dist dy))
       (if (and target-id
                (>= target-id 8)
                (<= target-id 78)
                (/= (mod target-id 9) 7))
       (setq ans-list (append ans-list (list target-id)))))
     (setq ans-list (remove-duplicates ans-list))
     ans-list
     )
   )

  (:inc-step () (setq step (1+ step)))

  (:change-state
   (state-list)
   (let (circle-list)
     (setq circle-list (send self :circle-list))
     (dolist (target-id circle-list)
       (setelt state-list target-id color)))
   )

)

(defun shift-board-id (bo-id x y)
  (let (ans)
    (if (<= bo-id 7) (setq bo-id (1- bo-id))) ;; 計算のため最上段を右に1つシフト
    (if (or (/= (/ (+ bo-id 1) 9) (/ (+ bo-id 1 x) 9))
            (= (+ bo-id x) -2))
        (return-from shift-board-id nil))
    (setq ans (+ bo-id x (* y 9)))
    (if (= ans 7) (return-from shift-board-id nil))
    (if (<= ans 6) (setq ans (1+ ans)))
    (if (or (< ans 0) (> ans 79)) (return-from shift-board-id nil))
    ans)
  )

;; atlasmarion/midi-gazebo-cotroller.lからコピペ
;; 1と1.0だと一致しないことに注意
(defun get-idx-from-value (l value)
  (let ((answer-idx nil))
    (dotimes (idx (length l))
      (if (equal (elt l idx) value) (setq answer-idx idx)))
    answer-idx))

(unix::sleep 1)
(setq *launchpad-ripple* (instance launchpad-ripple :init))
(ros::rate 30)
(while (ros::ok)
  (send *launchpad-ripple* :reset-state-list)
;;  (reset-led)
  (send *launchpad-ripple* :change-state-all)
  (send *launchpad-ripple* :inc-step-all)
  (send *launchpad-ripple* :statelist2led)
  (ros::spin-once)
  (ros::sleep))
