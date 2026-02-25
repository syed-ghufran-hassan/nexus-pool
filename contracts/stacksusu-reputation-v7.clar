;; StackSusu Reputation v8
;; Adds:
;; 1. Per-circle reputation
;; 2. Collateral scaling based on per-circle score
;; Keeps existing global reputation system intact

(define-constant CONTRACT-OWNER tx-sender)

;; Error constants
(define-constant ERR-NOT-FOUND (err u2001))
(define-constant ERR-INVALID-SCORE (err u2002))
(define-constant ERR-INIT-FAILED (err u2003))
(define-constant ERR_CIRCLE_NOT_FOUND (err u2004))

;; Score configuration
(define-constant BASE-SCORE u500)
(define-constant MAX-SCORE u1000)
(define-constant MIN-SCORE u0)
(define-constant MIN_REPUTATION_FLOOR u0)
(define-constant DECAY_PRECISION u10000)

;; ============================================
;; GLOBAL MEMBER REPUTATION (UNCHANGED)
;; ============================================

(define-map member-reputation
  principal
  {
    score: uint,
    contributions-made: uint,
    contributions-missed: uint,
    payouts-received: uint,
    circles-joined: uint,
    circles-completed: uint,
    last-activity: uint,
    initialized: bool
  }
)

;; ============================================
;; NEW: PER-CIRCLE REPUTATION
;; ============================================

(define-map member-circle-reputation
  { member: principal, circle-id: uint }
  {
    score: uint,
    contributions-made: uint,
    contributions-missed: uint,
    circles-completed: uint,
    last-activity: uint
  }
)

;; ============================================
;; Helpers
;; ============================================

(define-private (get-min (a uint) (b uint))
  (if (<= a b) a b)
)

(define-private (get-or-default-circle (member principal) (circle-id uint))
  (default-to
    {
      score: BASE-SCORE,
      contributions-made: u0,
      contributions-missed: u0,
      circles-completed: u0,
      last-activity: block-height
    }
    (map-get? member-circle-reputation { member: member, circle-id: circle-id })
  )
)

;; ============================================
;; EXISTING GLOBAL FUNCTIONS (UNCHANGED)
;; ============================================

(define-public (initialize-member (member principal))
  (begin
    (if (is-none (map-get? member-reputation member))
      (map-set member-reputation member {
        score: BASE-SCORE,
        contributions-made: u0,
        contributions-missed: u0,
        payouts-received: u0,
        circles-joined: u0,
        circles-completed: u0,
        last-activity: block-height,
        initialized: true
      })
      true
    )
    (ok true)
  )
)

;; (Global record functions unchanged from your original contract)
;; For brevity, assume all your existing global functions remain here
;; You can paste them exactly as-is below this comment.

;; ============================================
;; NEW: PER-CIRCLE RECORDING FUNCTIONS
;; ============================================

(define-public (record-circle-contribution (member principal) (circle-id uint))
  (let
    (
      (rep (get-or-default-circle member circle-id))
      (new-score (get-min MAX-SCORE (+ (get score rep) u10)))
    )
    (map-set member-circle-reputation
      { member: member, circle-id: circle-id }
      (merge rep {
        score: new-score,
        contributions-made: (+ (get contributions-made rep) u1),
        last-activity: block-height
      })
    )
    (ok new-score)
  )
)

(define-public (record-circle-missed-contribution (member principal) (circle-id uint))
  (let
    (
      (rep (get-or-default-circle member circle-id))
      (penalty (get-min (get score rep) u25))
      (new-score (- (get score rep) penalty))
    )
    (map-set member-circle-reputation
      { member: member, circle-id: circle-id }
      (merge rep {
        score: new-score,
        contributions-missed: (+ (get contributions-missed rep) u1),
        last-activity: block-height
      })
    )
    (ok new-score)
  )
)

(define-public (record-circle-complete (member principal) (circle-id uint))
  (let
    (
      (rep (get-or-default-circle member circle-id))
      (bonus (get-min u50 (- MAX-SCORE (get score rep))))
    )
    (map-set member-circle-reputation
      { member: member, circle-id: circle-id }
      (merge rep {
        score: (+ (get score rep) bonus),
        circles-completed: (+ (get circles-completed rep) u1),
        last-activity: block-height
      })
    )
    (ok true)
  )
)

;; ============================================
;; NEW: COLLATERAL SCALING
;; ============================================

;; required-collateral = stake * (MAX_SCORE - score) / MAX_SCORE

(define-read-only (calculate-required-collateral
  (member principal)
  (circle-id uint)
  (stake uint)
)
  (let
    (
      (rep (get-or-default-circle member circle-id))
      (score (get score rep))
      (risk-factor (- MAX-SCORE score))
      (required (/ (* stake risk-factor) MAX-SCORE))
    )
    (ok required)
  )
)

;; ============================================
;; NEW: PER-CIRCLE READ FUNCTIONS
;; ============================================

(define-read-only (get-circle-reputation
  (member principal)
  (circle-id uint)
)
  (ok (get-or-default-circle member circle-id))
)

(define-read-only (get-circle-score
  (member principal)
  (circle-id uint)
)
  (ok (get score (get-or-default-circle member circle-id)))
)
