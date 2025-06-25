;; LearnLedger - Track educational milestones on-chain
;; A smart contract for recording and verifying educational achievements

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-input (err u104))

;; Data Variables
(define-data-var next-milestone-id uint u1)
(define-data-var contract-active bool true)

;; Data Maps
(define-map milestones
  { milestone-id: uint }
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    category: (string-ascii 50),
    difficulty-level: uint,
    points: uint,
    created-at: uint,
    is-active: bool
  }
)

(define-map user-achievements
  { user: principal, milestone-id: uint }
  {
    completed-at: uint,
    verified: bool,
    verifier: (optional principal),
    proof-hash: (optional (buff 32))
  }
)

(define-map user-stats
  { user: principal }
  {
    total-points: uint,
    milestones-completed: uint,
    milestones-verified: uint,
    join-date: uint
  }
)

(define-map milestone-completions
  { milestone-id: uint }
  {
    total-completions: uint,
    verified-completions: uint
  }
)

(define-map verifiers
  { verifier: principal }
  {
    is-authorized: bool,
    verified-count: uint,
    added-at: uint
  }
)

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner)
)

(define-private (is-authorized-verifier (verifier principal))
  (default-to false 
    (get is-authorized (map-get? verifiers { verifier: verifier }))
  )
)

(define-private (update-user-stats (user principal) (points uint))
  (let ((current-stats (default-to 
                         { total-points: u0, milestones-completed: u0, milestones-verified: u0, join-date: block-height }
                         (map-get? user-stats { user: user }))))
    (map-set user-stats
      { user: user }
      {
        total-points: (+ (get total-points current-stats) points),
        milestones-completed: (+ (get milestones-completed current-stats) u1),
        milestones-verified: (get milestones-verified current-stats),
        join-date: (get join-date current-stats)
      }
    )
  )
)

(define-private (update-milestone-completions (milestone-id uint))
  (let ((current-completions (default-to 
                               { total-completions: u0, verified-completions: u0 }
                               (map-get? milestone-completions { milestone-id: milestone-id }))))
    (map-set milestone-completions
      { milestone-id: milestone-id }
      {
        total-completions: (+ (get total-completions current-completions) u1),
        verified-completions: (get verified-completions current-completions)
      }
    )
  )
)

;; Public Functions

;; Create a new milestone
(define-public (create-milestone (title (string-ascii 100)) 
                                (description (string-ascii 500))
                                (category (string-ascii 50))
                                (difficulty-level uint)
                                (points uint))
  (let ((milestone-id (var-get next-milestone-id)))
    (asserts! (var-get contract-active) err-unauthorized)
    (asserts! (> (len title) u0) err-invalid-input)
    (asserts! (and (>= difficulty-level u1) (<= difficulty-level u5)) err-invalid-input)
    (asserts! (> points u0) err-invalid-input)
    
    (map-set milestones
      { milestone-id: milestone-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        category: category,
        difficulty-level: difficulty-level,
        points: points,
        created-at: block-height,
        is-active: true
      }
    )
    
    (var-set next-milestone-id (+ milestone-id u1))
    (ok milestone-id)
  )
)

;; Complete a milestone
(define-public (complete-milestone (milestone-id uint) (proof-hash (optional (buff 32))))
  (let ((milestone (unwrap! (map-get? milestones { milestone-id: milestone-id }) err-not-found)))
    (asserts! (var-get contract-active) err-unauthorized)
    (asserts! (get is-active milestone) err-not-found)
    (asserts! (is-none (map-get? user-achievements { user: tx-sender, milestone-id: milestone-id })) err-already-exists)
    
    (map-set user-achievements
      { user: tx-sender, milestone-id: milestone-id }
      {
        completed-at: block-height,
        verified: false,
        verifier: none,
        proof-hash: proof-hash
      }
    )
    
    (update-user-stats tx-sender (get points milestone))
    (update-milestone-completions milestone-id)
    (ok true)
  )
)

;; Verify a user's milestone completion
(define-public (verify-milestone (user principal) (milestone-id uint))
  (let ((achievement (unwrap! (map-get? user-achievements { user: user, milestone-id: milestone-id }) err-not-found))
        (milestone (unwrap! (map-get? milestones { milestone-id: milestone-id }) err-not-found)))
    (asserts! (var-get contract-active) err-unauthorized)
    (asserts! (or (is-contract-owner) (is-authorized-verifier tx-sender)) err-unauthorized)
    (asserts! (not (get verified achievement)) err-already-exists)
    
    (map-set user-achievements
      { user: user, milestone-id: milestone-id }
      (merge achievement { verified: true, verifier: (some tx-sender) })
    )
    
    ;; Update user verified count
    (let ((user-stats-current (unwrap! (map-get? user-stats { user: user }) err-not-found)))
      (map-set user-stats
        { user: user }
        (merge user-stats-current 
               { milestones-verified: (+ (get milestones-verified user-stats-current) u1) })
      )
    )
    
    ;; Update milestone verified completions
    (let ((completions (default-to 
                         { total-completions: u0, verified-completions: u0 }
                         (map-get? milestone-completions { milestone-id: milestone-id }))))
      (map-set milestone-completions
        { milestone-id: milestone-id }
        (merge completions { verified-completions: (+ (get verified-completions completions) u1) })
      )
    )
    
    ;; Update verifier stats
    (let ((verifier-stats (unwrap! (map-get? verifiers { verifier: tx-sender }) err-unauthorized)))
      (map-set verifiers
        { verifier: tx-sender }
        (merge verifier-stats { verified-count: (+ (get verified-count verifier-stats) u1) })
      )
    )
    
    (ok true)
  )
)

;; Add authorized verifier (owner only)
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (asserts! (var-get contract-active) err-unauthorized)
    (asserts! (is-none (map-get? verifiers { verifier: verifier })) err-already-exists)
    
    (map-set verifiers
      { verifier: verifier }
      { is-authorized: true, verified-count: u0, added-at: block-height })
    (ok true)
  )
)

;; Remove verifier authorization (owner only)
(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (asserts! (var-get contract-active) err-unauthorized)
    (asserts! (is-some (map-get? verifiers { verifier: verifier })) err-not-found)
    
    (map-set verifiers
      { verifier: verifier }
      { is-authorized: false, verified-count: u0, added-at: block-height })
    (ok true)
  )
)

;; Deactivate milestone (creator or owner only)
(define-public (deactivate-milestone (milestone-id uint))
  (let ((milestone (unwrap! (map-get? milestones { milestone-id: milestone-id }) err-not-found)))
    (asserts! (var-get contract-active) err-unauthorized)
    (asserts! (or (is-contract-owner) (is-eq tx-sender (get creator milestone))) err-unauthorized)
    
    (map-set milestones
      { milestone-id: milestone-id }
      (merge milestone { is-active: false })
    )
    (ok true)
  )
)

;; Emergency pause contract (owner only)
(define-public (toggle-contract-active)
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (var-set contract-active (not (var-get contract-active)))
    (ok (var-get contract-active))
  )
)

;; Read-only functions

;; Get milestone details
(define-read-only (get-milestone (milestone-id uint))
  (map-get? milestones { milestone-id: milestone-id })
)

;; Get user achievement
(define-read-only (get-user-achievement (user principal) (milestone-id uint))
  (map-get? user-achievements { user: user, milestone-id: milestone-id })
)

;; Get user statistics
(define-read-only (get-user-stats (user principal))
  (map-get? user-stats { user: user })
)

;; Get milestone completion statistics
(define-read-only (get-milestone-stats (milestone-id uint))
  (map-get? milestone-completions { milestone-id: milestone-id })
)

;; Check if user completed milestone
(define-read-only (has-completed-milestone (user principal) (milestone-id uint))
  (is-some (map-get? user-achievements { user: user, milestone-id: milestone-id }))
)

;; Check if milestone is verified for user
(define-read-only (is-milestone-verified (user principal) (milestone-id uint))
  (match (map-get? user-achievements { user: user, milestone-id: milestone-id })
    achievement (get verified achievement)
    false
  )
)

;; Get next milestone ID
(define-read-only (get-next-milestone-id)
  (var-get next-milestone-id)
)

;; Check if contract is active
(define-read-only (is-contract-active)
  (var-get contract-active)
)

;; Check if principal is authorized verifier
(define-read-only (is-verifier (verifier principal))
  (is-authorized-verifier verifier)
)

;; Get contract owner
(define-read-only (get-contract-owner)
  contract-owner
)