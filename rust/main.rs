use alloy::{dyn_abi::SolType, sol_types::SolStruct};
use arbiter::compact_types::*;

use clap::{Parser, ValueEnum};

#[derive(Parser, Debug, Clone, PartialEq, Eq, clap::ValueEnum)]
enum Modes {
    TypeHash,
    TypeString,
    Hash,
}

#[derive(Parser, Debug)]
#[command(author, version, about = "A tool for handling blockchain intents", long_about = None)]
struct Args {
    #[arg(short = 'm', long, help = "set the mode of operation (TypeHash, Hash)")]
    mode: Modes,
    /// The signed intent as a hexadecimal string (e.g., 0x11AABBCC)
    #[arg(
        short = 't',
        long,
        required_if_eq("mode", "Typehash"),
        help = "enter name of EIP712 struct"
    )]
    typehash: Option<String>,

    #[arg(
        short = 's',
        long,
        required_if_eq("mode", "Typestring"),
        help = "enter name of EIP712 struct"
    )]
    typestring: Option<String>,

    #[arg(
        help = "Bytes to decode (hex format starting with 0x)",
        required_if_eq("mode", "Hash")
    )]
    bytes: Option<String>,
}
// Enum for valid typehash names (placeholders for now)
#[derive(Debug, Clone, PartialEq, Eq, ValueEnum)]
enum EIP712Struct {
    MultichainCompact,
    Element,
    Mandate,
    Target,
    Lock,
    Token,
    QualifiedClaim,
    Operation,
}

impl EIP712Struct {
    fn from_str(input: &str) -> Option<Self> {
        match input.to_lowercase().as_str() {
            "multichaincompact" => Some(EIP712Struct::MultichainCompact),
            "mandate" => Some(EIP712Struct::Mandate),
            "element" => Some(EIP712Struct::Element),
            "target" => Some(EIP712Struct::Target),
            "lock" => Some(EIP712Struct::Lock),
            "token" => Some(EIP712Struct::Token),
            "operation" => Some(EIP712Struct::Operation),
            "qualification" => Some(EIP712Struct::QualifiedClaim),

            _ => None,
        }
    }
}

fn main() {
    let args = Args::parse();

    match args.mode {
        Modes::TypeHash => print_typehash(args),
        Modes::TypeString => print_typestring(args),
        Modes::Hash => print_hash(args),
    }
}

fn print_typehash(args: Args) {
    // Ensure the user has provided a valid typehash name
    //
    if let Some(typehash_str) = args.typehash {
        match EIP712Struct::from_str(&typehash_str) {
            Some(EIP712Struct::MultichainCompact) => {
                let compact = MultichainCompact::mock();
                println!("{:?}", MultichainCompact::eip712_type_hash(&compact));
            }

            Some(EIP712Struct::Mandate) => {
                let compact = MultichainCompact::mock();
                println!(
                    "{:?}",
                    Mandate::eip712_type_hash(&compact.elements[0].mandate)
                );
            }
            Some(EIP712Struct::Element) => {
                let compact = MultichainCompact::mock();
                println!("{:?}", Element::eip712_type_hash(&compact.elements[0]));
                // Add logic related to this type hash here
            }

            Some(EIP712Struct::Target) => {
                let target = Target::mock();
                println!("{:?}", Target::eip712_type_hash(&target));
            }

            Some(EIP712Struct::Lock) => {
                let lock = Lock::mock();
                println!("{:?}", Lock::eip712_type_hash(&lock));
            }

            Some(EIP712Struct::Token) => {
                let token = Token::mock();
                println!("{:?}", Token::eip712_type_hash(&token));
            }

            Some(EIP712Struct::Operation) => {
                // Add logic related to this type hash here
                let execution = Op::mock();
                println!("{:?}", Op::eip712_type_hash(&execution));
            }

            Some(EIP712Struct::QualifiedClaim) => {
                // Add logic related to this type hash here
                let data = QualifiedClaim::mock();
                println!("{:?}", QualifiedClaim::eip712_type_hash(&data));
            }

            None => {
                eprintln!("Invalid typehash name provided.");
            }
        }
    } else {
        eprintln!("You must provide a typehash name when in TypeHash mode.");
    }
}

fn print_typestring(args: Args) {
    // Ensure the user has provided a valid typestring name
    //
    if let Some(typestring_str) = args.typestring {
        match EIP712Struct::from_str(&typestring_str) {
            Some(EIP712Struct::MultichainCompact) => {
                println!("{:?}", MultichainCompact::eip712_root_type());
                println!("{:?}", MultichainCompact::eip712_components());
            }

            Some(EIP712Struct::Mandate) => {
                println!("{:?}", Mandate::eip712_root_type());
                println!("{:?}", Mandate::eip712_components());
            }
            Some(EIP712Struct::Element) => {
                println!("{:?}", Element::eip712_root_type());
                println!("{:?}", Element::eip712_components());
            }

            Some(EIP712Struct::Target) => {
                println!("{:?}", Target::eip712_root_type());
                println!("{:?}", Target::eip712_components());
            }

            Some(EIP712Struct::Lock) => {
                println!("{:?}", Lock::eip712_root_type());
            }

            Some(EIP712Struct::Token) => {
                println!("{:?}", Token::eip712_root_type());
            }

            Some(EIP712Struct::Operation) => {
                println!("{:?}", Op::eip712_root_type());
            }

            Some(EIP712Struct::QualifiedClaim) => {
                println!("{:?}", QualifiedClaim::eip712_root_type());
            }

            None => {
                eprintln!("Invalid typehash name provided.");
            }
        }
    } else {
        eprintln!("You must provide a typehash name when in TypeString mode.");
    }
}
fn print_hash(args: Args) {
    let bytes = match args.bytes {
        Some(hex_str) => {
            if !hex_str.starts_with("0x") {
                eprintln!("Bytes must start with 0x");
                return;
            }
            match hex::decode(&hex_str[2..]) {
                Ok(bytes) => bytes,
                Err(e) => {
                    eprintln!("Failed to decode hex string: {}", e);
                    return;
                }
            }
        }
        None => {
            eprintln!("Bytes parameter is required for hash mode");
            return;
        }
    };

    if let Some(name) = args.typehash {
        match EIP712Struct::from_str(&name) {
            Some(EIP712Struct::MultichainCompact) => {
                match MultichainCompact::abi_decode(&bytes, true) {
                    Ok(decoded) => {
                        println!("{:?}", MultichainCompact::eip712_hash_struct(&decoded))
                    }
                    Err(e) => eprintln!("Failed to decode MultichainCompact: {:?}", e),
                }
            }

            Some(EIP712Struct::Mandate) => match Mandate::abi_decode(&bytes, true) {
                Ok(decoded) => println!("{:?}", Mandate::eip712_hash_struct(&decoded)),
                Err(e) => eprintln!("Failed to decode Mandate: {:?}", e),
            },
            Some(EIP712Struct::Element) => match Element::abi_decode(&bytes, true) {
                Ok(decoded) => println!("{:?}", Element::eip712_hash_struct(&decoded)),
                Err(e) => eprintln!("Failed to decode Element: {:?}", e),
            },

            Some(EIP712Struct::Target) => match Target::abi_decode(&bytes, true) {
                Ok(decoded) => println!("{:?}", Target::eip712_hash_struct(&decoded)),
                Err(e) => eprintln!("Failed to decode Target: {:?}", e),
            },

            Some(EIP712Struct::Lock) => match Lock::abi_decode(&bytes, true) {
                Ok(decoded) => println!("{:?}", Lock::eip712_hash_struct(&decoded)),
                Err(e) => eprintln!("Failed to decode Lock: {:?}", e),
            },

            Some(EIP712Struct::Token) => match Token::abi_decode(&bytes, true) {
                Ok(decoded) => println!("{:?}", Token::eip712_hash_struct(&decoded)),
                Err(e) => eprintln!("Failed to decode Token: {:?}", e),
            },

            Some(EIP712Struct::Operation) => match Op::abi_decode(&bytes, true) {
                Ok(decoded) => println!("{:?}", Op::eip712_hash_struct(&decoded)),
                Err(e) => eprintln!("Failed to decode Operation: {:?}", e),
            },

            Some(EIP712Struct::QualifiedClaim) => match QualifiedClaim::abi_decode(&bytes, true) {
                Ok(decoded) => {
                    println!("{:?}", QualifiedClaim::eip712_hash_struct(&decoded))
                }
                Err(e) => eprintln!("Failed to decode Execution: {:?}", e),
            },

            None => {
                eprintln!("Invalid typehash name provided.");
            }
        }
    } else {
        eprintln!("You must provide a typehash name when in TypeString mode.");
    }
}

// fn main() {
//
//
//     let compact = MultichainCompact::mock();
//     println!("MultichainCompact: {:?}", compact);
//     println!("MultichainCompact typehash: {:?}", MultichainCompact::eip712_type_hash(&compact));
//     println!("MultichainCompact root type: {}", MultichainCompact::eip712_root_type());
//
//
//     println!("Mandate type hash : {}", Mandate::eip712_type_hash(&compact.elements[0].mandate));
//     println!("Mandate type hash : {}", Mandate::eip712_type_hash(&compact.elements[0].mandate));
//     println!("{:?}", MultichainCompact::eip712_components());
//
//
// }
