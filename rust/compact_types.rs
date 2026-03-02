use alloy::{
    primitives::{address, bytes, fixed_bytes, U256},
    sol,
};

use serde::Serialize;

sol! {
    #[allow(missing_docs)]
    #[derive(Serialize, Debug,  PartialEq)]
    struct Ops{
        address to;
        uint256 value;
        bytes data;
    }

    #[allow(missing_docs)]
    #[derive(Serialize, Debug,  PartialEq)]
    struct Op{
        bytes32 vt;
        Ops[] ops;
    }

}

/* -------- ERC7579 types -------- */
sol! {
    #[allow(missing_docs)]
    #[derive(Serialize, Debug,  PartialEq)]
    struct MultichainCompact {
        address sponsor;
        uint256 nonce; // last depositId
        uint256 expires;
        Element[] elements;
    }

    #[allow(missing_docs)]
    #[derive(Serialize, Debug,  PartialEq)]
    struct Element {
        address arbiter;
        uint256 chainId;
        Lock[] commitments;
        Mandate mandate;
    }


    #[allow(missing_docs)]
    #[derive(Serialize, Debug,  PartialEq)]
    struct Lock {
        bytes12 lockTag;
        address token;
        uint256 amount;
    }


    #[allow(missing_docs)]
    #[derive(Serialize, Debug,  PartialEq)]
    struct Mandate {
        Target target;
        uint128 minGas;
        Op originOps;
        Op destOps;
        bytes32 q;
    }

    #[allow(missing_docs)]
    #[derive(Serialize, Debug,  PartialEq)]
    struct Target {
        address recipient;
        Token[] tokenOut;
        uint256 targetChain;
        uint256 fillExpiry;
    }

    #[allow(missing_docs)]
    #[derive(Serialize, Debug,  PartialEq)]
    struct Token {
        address token;
        uint256 amount;
    }


    #[allow(missing_docs)]
    #[derive(Serialize, Debug,  PartialEq)]
    struct QualifiedClaim {
        bytes32 claimHash;
        bytes32 qualificationHash;
    }

}

impl Mandate {
    pub fn mock() -> Self {
        Mandate {
            target: Target::mock(), // Use the mock for Target
            minGas: 0, // Default minGas value for mock
            originOps: Op::mock(),
            destOps: Op::mock(),
            q: fixed_bytes!("1234567890123456789012345678901234567890123456789012345678901234"), // Example bytes32 for q
        }
    }
}

impl Target {
    pub fn mock() -> Self {
        Target {
            recipient: address!("1111111111111111111111111111111111111111"),
            tokenOut: vec![Token::mock()],
            targetChain: U256::from(1),
            fillExpiry: U256::from(12341234),
        }
    }
}

impl Token {
    pub fn mock() -> Self {
        Token {
            token: address!("2222222222222222222222222222222222222222"),
            amount: U256::from(1000),
        }
    }
}

impl Lock {
    pub fn mock() -> Self {
        Lock {
            lockTag: fixed_bytes!("123456789012345678901234"), // Example bytes12 for lockTag (24 hex chars = 12 bytes)
            token: address!("3333333333333333333333333333333333333333"),
            amount: U256::from(500),
        }
    }
}

impl MultichainCompact {
    pub fn mock() -> Self {
        MultichainCompact {
            sponsor: address!("1111111111111111111111111111111111111111"),
            nonce: U256::from(1),
            expires: U256::from(1000),
            elements: vec![Element {
                arbiter: address!("1111111111111111111111111111111111111111"),
                chainId: U256::from(1),
                commitments: vec![Lock::mock()], // Use Lock::mock()
                mandate: Mandate::mock(),
            }],
        }
    }
}

impl Ops {
    pub fn mock() -> Self {
        Ops {
            to: address!("1111111111111111111111111111111111111111"),
            value: U256::from(1000),
            data: bytes!("1234567890123456789012345678901234567890123456789012345678901234"),
        }
    }
}

impl Op {
    pub fn mock() -> Self {
        Op {
            vt: fixed_bytes!("0000000000000000000000000000000000000000000000000000000000000000"),
            ops: vec![],
        }
    }
}

impl QualifiedClaim {
    pub fn mock() -> Self {
        QualifiedClaim {
            claimHash: fixed_bytes!(
                "1234567890123456789012345678901234567890123456789012345678901234"
            ),
            qualificationHash: fixed_bytes!(
                "1234567890123456789012345678901234567890123456789012345678901234"
            ),
        }
    }
}
