(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-member (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-proposal-not-found (err u103))
(define-constant err-already-voted (err u104))
(define-constant err-proposal-expired (err u105))

(define-data-var total-savings uint u0)
(define-data-var member-count uint u0)
(define-data-var proposal-count uint u0)

(define-map members
    principal
    {
        balance: uint,
        joined-height: uint,
        total-contributed: uint,
        reputation-score: uint,
    }
)

(define-map proposals
    uint
    {
        proposer: principal,
        amount: uint,
        description: (string-ascii 256),
        yes-votes: uint,
        no-votes: uint,
        executed: bool,
        deadline: uint,
        voters: (list 50 principal),
    }
)

(define-read-only (get-member-info (member principal))
    (default-to {
        balance: u0,
        joined-height: u0,
        total-contributed: u0,
        reputation-score: u0,
    }
        (map-get? members member)
    )
)

(define-read-only (get-proposal (id uint))
    (map-get? proposals id)
)

(define-read-only (get-total-savings)
    (var-get total-savings)
)

(define-read-only (get-member-count)
    (var-get member-count)
)

(define-read-only (calculate-voting-weight (member principal))
    (let (
            (member-data (get-member-info member))
            (tenure-blocks (- burn-block-height (get joined-height member-data)))
            (reputation (get reputation-score member-data))
            (contribution-base (/ (get total-contributed member-data) u1000))
            (contribution-factor (if (> contribution-base u50)
                u50
                contribution-base
            ))
            (tenure-base (/ tenure-blocks u1000))
            (tenure-factor (if (> tenure-base u25)
                u25
                tenure-base
            ))
            (reputation-base (/ reputation u10))
            (reputation-factor (if (> reputation-base u25)
                u25
                reputation-base
            ))
        )
        (+ u1 contribution-factor tenure-factor reputation-factor)
    )
)

(define-public (join-cooperative)
    (let ((height burn-block-height))
        (asserts! (is-none (map-get? members tx-sender)) (err u106))
        (map-set members tx-sender {
            balance: u0,
            joined-height: height,
            total-contributed: u0,
            reputation-score: u0,
        })
        (var-set member-count (+ (var-get member-count) u1))
        (ok true)
    )
)

(define-public (contribute (amount uint))
    (let (
            (member-data (unwrap! (map-get? members tx-sender) err-not-member))
            (new-balance (+ (get balance member-data) amount))
            (new-total-contributed (+ (get total-contributed member-data) amount))
        )
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set members tx-sender {
            balance: new-balance,
            joined-height: (get joined-height member-data),
            total-contributed: new-total-contributed,
            reputation-score: (+ (get reputation-score member-data) (/ amount u100)),
        })
        (var-set total-savings (+ (var-get total-savings) amount))
        (ok true)
    )
)

(define-public (create-proposal
        (amount uint)
        (description (string-ascii 256))
    )
    (let (
            (member-data (unwrap! (map-get? members tx-sender) err-not-member))
            (proposal-id (+ (var-get proposal-count) u1))
            (deadline (+ burn-block-height u144))
        )
        (asserts! (<= amount (var-get total-savings)) err-insufficient-balance)
        (map-set proposals proposal-id {
            proposer: tx-sender,
            amount: amount,
            description: description,
            yes-votes: u0,
            no-votes: u0,
            executed: false,
            deadline: deadline,
            voters: (list),
        })
        (var-set proposal-count proposal-id)
        (ok proposal-id)
    )
)

(define-public (vote-on-proposal
        (proposal-id uint)
        (vote bool)
    )
    (let (
            (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
            (member-data (unwrap! (map-get? members tx-sender) err-not-member))
            (voters (get voters proposal))
            (member-weight (calculate-voting-weight tx-sender))
        )
        (asserts! (< burn-block-height (get deadline proposal))
            err-proposal-expired
        )
        (asserts! (is-none (index-of voters tx-sender)) err-already-voted)
        (map-set proposals proposal-id
            (merge proposal {
                yes-votes: (if vote
                    (+ (get yes-votes proposal) member-weight)
                    (get yes-votes proposal)
                ),
                no-votes: (if vote
                    (get no-votes proposal)
                    (+ (get no-votes proposal) member-weight)
                ),
                voters: (unwrap! (as-max-len? (append voters tx-sender) u50)
                    err-owner-only
                ),
            })
        )
        (ok true)
    )
)

(define-public (execute-proposal (proposal-id uint))
    (let (
            (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
            (total-votes (+ (get yes-votes proposal) (get no-votes proposal)))
        )
        (asserts! (>= burn-block-height (get deadline proposal))
            err-proposal-expired
        )
        (asserts! (not (get executed proposal)) (err u107))
        (asserts! (> (get yes-votes proposal) (get no-votes proposal)) (err u108))
        (try! (as-contract (stx-transfer? (get amount proposal) (as-contract tx-sender)
            (get proposer proposal)
        )))
        (map-set proposals proposal-id (merge proposal { executed: true }))
        (var-set total-savings (- (var-get total-savings) (get amount proposal)))
        (ok true)
    )
)

(define-public (withdraw (amount uint))
    (let (
            (member-data (unwrap! (map-get? members tx-sender) err-not-member))
            (current-balance (get balance member-data))
        )
        (asserts! (>= current-balance amount) err-insufficient-balance)
        (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))
        (map-set members tx-sender
            (merge member-data { balance: (- current-balance amount) })
        )
        (var-set total-savings (- (var-get total-savings) amount))
        (ok true)
    )
)
