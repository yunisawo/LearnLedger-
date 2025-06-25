# LearnLedger 📚⛓️

**Track educational milestones on-chain with verifiable achievements.**

LearnLedger is a Clarity smart contract built for the Stacks blockchain that enables users to create, complete, and verify educational milestones in a decentralized, transparent manner. Perfect for online courses, bootcamps, educational institutions, and self-directed learning programs.

## 🌟 Features

### Core Functionality
- **Milestone Creation**: Anyone can create educational milestones with detailed metadata
- **Achievement Tracking**: Users complete milestones and earn points
- **Verification System**: Authorized verifiers can validate milestone completions
- **Statistics Dashboard**: Comprehensive tracking of user progress and milestone popularity
- **Proof Submission**: Optional cryptographic proof hashes for completion evidence

### Security & Governance
- **Access Control**: Owner-controlled verifier authorization system
- **Emergency Controls**: Contract pause functionality for security
- **Data Integrity**: Prevents duplicate completions and unauthorized modifications
- **Transparent History**: All achievements permanently recorded on-chain

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic understanding of Clarity smart contracts
- Stacks wallet for deployment

### Installation

1. **Clone or create your project directory**
```bash
mkdir learn-ledger
cd learn-ledger
clarinet new .
```

2. **Add the contract**
```bash
# Copy the LearnLedger contract to contracts/learn-ledger.clar
```

3. **Update Clarinet.toml**
```toml
[contracts.learn-ledger]
path = "contracts/learn-ledger.clar"
```

4. **Test the contract**
```bash
clarinet check
clarinet test
```

## 📖 Usage Guide

### Creating Milestones

Anyone can create educational milestones:

```clarity
(contract-call? .learn-ledger create-milestone 
  "Complete React Fundamentals" 
  "Learn React components, state, and hooks through hands-on projects"
  "Web Development"
  u3  ;; difficulty level (1-5)
  u100 ;; points awarded
)
```

**Parameters:**
- `title`: Milestone name (max 100 characters)
- `description`: Detailed description (max 500 characters)  
- `category`: Subject category (max 50 characters)
- `difficulty-level`: 1 (beginner) to 5 (expert)
- `points`: Points awarded upon completion

### Completing Milestones

Users complete milestones to earn points:

```clarity
(contract-call? .learn-ledger complete-milestone 
  u1 ;; milestone ID
  (some 0x1234567890abcdef...) ;; optional proof hash
)
```

### Verification System

Authorized verifiers can validate completions:

```clarity
;; Owner adds verifier
(contract-call? .learn-ledger add-verifier 'SP1VERIFIER...)

;; Verifier validates completion
(contract-call? .learn-ledger verify-milestone 
  'SP1STUDENT... ;; user principal
  u1 ;; milestone ID
)
```

### Querying Data

Check user progress and milestone details:

```clarity
;; Get user statistics
(contract-call? .learn-ledger get-user-stats 'SP1USER...)

;; Check milestone completion
(contract-call? .learn-ledger has-completed-milestone 'SP1USER... u1)

;; Get milestone details
(contract-call? .learn-ledger get-milestone u1)
```

## 🏗️ Contract Architecture

### Data Structures

#### Milestones
```clarity
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
```

#### User Achievements
```clarity
{
  completed-at: uint,
  verified: bool,
  verifier: (optional principal),
  proof-hash: (optional (buff 32))
}
```

#### User Statistics
```clarity
{
  total-points: uint,
  milestones-completed: uint,
  milestones-verified: uint,
  join-date: uint
}
```

### Key Functions

#### Public Functions
- `create-milestone` - Create new educational milestone
- `complete-milestone` - Mark milestone as completed
- `verify-milestone` - Verify user's milestone completion
- `add-verifier` - Authorize new verifier (owner only)
- `remove-verifier` - Remove verifier authorization (owner only)
- `deactivate-milestone` - Disable milestone (creator/owner only)
- `toggle-contract-active` - Emergency pause (owner only)

#### Read-Only Functions
- `get-milestone` - Retrieve milestone details
- `get-user-achievement` - Get specific user achievement
- `get-user-stats` - Get comprehensive user statistics
- `get-milestone-stats` - Get milestone completion statistics
- `has-completed-milestone` - Check completion status
- `is-milestone-verified` - Check verification status
- `is-verifier` - Check verifier authorization

## 🔒 Security Considerations

### Access Control
- **Contract Owner**: Can add/remove verifiers, pause contract
- **Milestone Creators**: Can deactivate their own milestones
- **Authorized Verifiers**: Can verify milestone completions
- **Regular Users**: Can create milestones and complete them

### Error Handling
The contract includes comprehensive error codes:
- `u100`: Owner-only operation attempted by non-owner
- `u101`: Requested data not found
- `u102`: Resource already exists (duplicate)
- `u103`: Unauthorized operation
- `u104`: Invalid input parameters

### Best Practices
1. **Verifier Management**: Carefully vet verifiers before authorization
2. **Proof Hashes**: Use for high-stakes certifications requiring evidence
3. **Milestone Categories**: Establish consistent category naming conventions
4. **Emergency Procedures**: Keep owner keys secure for contract management

## 📊 Use Cases

### Educational Institutions
- **Universities**: Track degree requirements and course completions
- **Online Platforms**: Gamify learning with point systems
- **Professional Training**: Verify skill certifications
