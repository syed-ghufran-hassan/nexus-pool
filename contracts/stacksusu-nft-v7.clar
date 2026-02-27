;; ============================================================
;; StackSusu NFT v8 (Production Refactor)
;; ============================================================

;; ================= CONSTANTS =================

(define-constant ERR-NOT-AUTHORIZED (err u5000))
(define-constant ERR-NOT-FOUND (err u5001))
(define-constant ERR-ALREADY-MINTED (err u5002))
(define-constant ERR-INVALID-TYPE (err u5003))
(define-constant ERR-LIST-OVERFLOW (err u5004))

(define-constant TYPE-MEMBER-BADGE u1)
(define-constant TYPE-CIRCLE-COMPLETE u2)
(define-constant TYPE-TOP-CONTRIBUTOR u3)
(define-constant TYPE-EARLY-ADOPTER u4)
(define-constant TYPE-REPUTATION-TIER u5)

;; ================= STATE =================

(define-data-var contract-owner principal tx-sender)
(define-data-var nft-counter uint u0)

(define-map nfts
  uint
  {
    owner: principal,
    nft-type: uint,
    metadata: (string-ascii 200),
    minted-at: uint,
    circle-id: (optional uint)
  }
)

(define-map owner-nfts
  principal
  (list 50 uint)
)

(define-map minted-badges
  { owner: principal, nft-type: uint }
  bool
)

;; ============================================================
;; INTERNAL HELPERS
;; ============================================================

(define-private (assert-owner)
  (asserts! (is-eq tx-sender (var-get contract-owner))
            ERR-NOT-AUTHORIZED)
)

(define-private (add-to-owner (user principal) (token-id uint))
  (let ((existing (default-to (list) (map-get? owner-nfts user))))
    (unwrap!
      (map-set owner-nfts user
        (as-max-len? (append existing token-id) u50))
      ERR-LIST-OVERFLOW)
  )
)

(define-private (remove-from-owner (user principal) (token-id uint))
  (let (
        (existing (default-to (list) (map-get? owner-nfts user)))
        (filtered (filter (lambda (id) (not (is-eq id token-id))) existing))
       )
    (map-set owner-nfts user filtered)
  )
)

(define-private (mint-internal
  (recipient principal)
  (nft-type uint)
  (metadata (string-ascii 200))
  (circle-id (optional uint))
)
  (let ((token-id (+ (var-get nft-counter) u1)))
    (map-set nfts token-id {
      owner: recipient,
      nft-type: nft-type,
      metadata: metadata,
      minted-at: stacks-block-height,
      circle-id: circle-id
    })

    (add-to-owner recipient token-id)

    (var-set nft-counter token-id)
    token-id
  )
)

;; ============================================================
;; ADMIN
;; ============================================================

(define-public (set-contract-owner (new-owner principal))
  (begin
    (assert-owner)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; ============================================================
;; MINT FUNCTIONS (Admin Only)
;; ============================================================

(define-public (mint-member-badge (member principal))
  (begin
    (assert-owner)

    (asserts!
      (not (default-to false
            (map-get? minted-badges
              { owner: member, nft-type: TYPE-MEMBER-BADGE })))
      ERR-ALREADY-MINTED)

    (let ((token-id
            (mint-internal
              member
              TYPE-MEMBER-BADGE
              "StackSusu Member Badge"
              none)))
      (map-set minted-badges
        { owner: member, nft-type: TYPE-MEMBER-BADGE }
        true)
      (ok token-id)
    )
  )
)

(define-public (mint-circle-completion
  (member principal)
  (circle-id uint))
  (begin
    (assert-owner)
    (ok
      (mint-internal
        member
        TYPE-CIRCLE-COMPLETE
        "Circle Completion Achievement"
        (some circle-id)))
  )
)

(define-public (mint-reputation-badge
  (member principal)
  (tier uint))
  (begin
    (assert-owner)

    (asserts!
      (and (>= tier u1) (<= tier u5))
      ERR-INVALID-TYPE)

    (let (
          (tier-name
            (if (is-eq tier u5) "Legendary"
            (if (is-eq tier u4) "Expert"
            (if (is-eq tier u3) "Advanced"
            (if (is-eq tier u2) "Intermediate"
                                 "Beginner"))))))
         )
      (ok
        (mint-internal
          member
          TYPE-REPUTATION-TIER
          tier-name
          none))
    )
  )
)

;; ============================================================
;; TRANSFER
;; ============================================================

(define-public (transfer (token-id uint) (recipient principal))
  (let ((nft (unwrap! (map-get? nfts token-id)
                     ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner nft))
              ERR-NOT-AUTHORIZED)

    ;; Remove from previous owner
    (remove-from-owner (get owner nft) token-id)

    ;; Update owner
    (map-set nfts token-id
      (merge nft { owner: recipient }))

    ;; Add to new owner
    (add-to-owner recipient token-id)

    (ok true)
  )
)

;; ============================================================
;; READ FUNCTIONS
;; ============================================================

(define-read-only (get-nft (token-id uint))
  (map-get? nfts token-id)
)

(define-read-only (get-owner (token-id uint))
  (match (map-get? nfts token-id)
    nft (ok (some (get owner nft)))
    (ok none))
)

(define-read-only (get-nft-count)
  (var-get nft-counter)
)

(define-read-only (get-owner-nfts (owner principal))
  (default-to (list) (map-get? owner-nfts owner))
)

(define-read-only (has-badge (owner principal) (nft-type uint))
  (default-to false
    (map-get? minted-badges
      { owner: owner, nft-type: nft-type }))
)
