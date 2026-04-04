#!/usr/bin/env python3
"""Generate test contacts for stress testing the iOS contacts bridge app.

All generated contacts have a configurable name prefix (default "ZZTest") so they
can be identified and bulk-deleted later.

Usage:
    python scripts/generate_contacts.py                        # 1000 contacts
    python scripts/generate_contacts.py --count 5000           # custom count
    python scripts/generate_contacts.py --cleanup              # delete from macOS Contacts
    python scripts/generate_contacts.py --prefix "XXBench"     # custom prefix
"""

import argparse
import os
import random
import sys

PREFIX_DEFAULT = "ZZTest"
COUNT_DEFAULT = 1000

FIRST_NAMES = [
    "Alice", "Bob", "Carlos", "Diana", "Elena", "Frank", "Grace", "Hassan",
    "Iris", "James", "Karen", "Leo", "Maya", "Nathan", "Olivia", "Paul",
    "Quinn", "Rosa", "Sam", "Tina", "Uma", "Victor", "Wendy", "Xavier",
    "Yuki", "Zara", "Aaron", "Bella", "Chris", "Dana", "Eric", "Fiona",
    "George", "Hannah", "Ivan", "Julia", "Kevin", "Luna", "Marco", "Nina",
    "Oscar", "Priya", "Rafael", "Sofia", "Thomas", "Ursula", "Vincent",
    "Willow", "Xena", "Yolanda",
]

LAST_NAMES = [
    "Smith", "Johnson", "Garcia", "Chen", "Kim", "Patel", "Brown", "Williams",
    "Jones", "Miller", "Davis", "Wilson", "Taylor", "Anderson", "Thomas",
    "Jackson", "White", "Harris", "Martin", "Thompson", "Moore", "Young",
    "Allen", "King", "Wright", "Lopez", "Hill", "Scott", "Green", "Adams",
    "Baker", "Nelson", "Carter", "Mitchell", "Perez", "Roberts", "Turner",
    "Phillips", "Campbell", "Parker", "Evans", "Edwards", "Collins", "Stewart",
    "Sanchez", "Morris", "Rogers", "Reed", "Cook", "Morgan",
]


def generate_phone() -> str:
    area = random.randint(200, 999)
    mid = random.randint(200, 999)
    last = random.randint(1000, 9999)
    return f"+1{area}{mid}{last}"


def generate_vcard(given: str, family: str, phones: list) -> str:
    lines = [
        "BEGIN:VCARD",
        "VERSION:3.0",
        f"FN:{given} {family}",
        f"N:{family};{given};;;",
    ]
    for phone in phones:
        lines.append(f"TEL;TYPE=CELL:{phone}")
    lines.append("END:VCARD")
    return "\n".join(lines)


def generate_vcf_file(count: int, prefix: str, output_path: str) -> None:
    vcards = []
    for _ in range(count):
        given = prefix + random.choice(FIRST_NAMES)
        family = random.choice(LAST_NAMES)
        num_phones = random.choices([1, 2, 3], weights=[60, 30, 10])[0]
        phones = [generate_phone() for _ in range(num_phones)]
        vcards.append(generate_vcard(given, family, phones))

    output_dir = os.path.dirname(output_path)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)

    with open(output_path, "w") as f:
        f.write("\n".join(vcards) + "\n")

    print(f"Generated {count} contacts → {output_path}")
    print(f"All contacts have given names starting with '{prefix}'")
    print(f"Import on device: AirDrop the .vcf file or open it in Files app")


def cleanup_contacts(prefix: str) -> None:
    if sys.platform != "darwin":
        print("Error: Cleanup only works on macOS (uses Contacts framework via pyobjc)")
        sys.exit(1)

    try:
        import Contacts  # pyobjc-framework-Contacts
    except ImportError:
        print("Error: pyobjc-framework-Contacts not installed")
        print("Install with: pip install pyobjc-framework-Contacts")
        sys.exit(1)

    store = Contacts.CNContactStore.alloc().init()

    # Request access
    granted, error = store.requestAccessForEntityType_completionHandler_(
        Contacts.CNEntityTypeContacts, None
    )
    if not granted:
        print("Error: Contacts access denied. Grant access in System Settings → Privacy → Contacts")
        sys.exit(1)

    # Fetch all contacts with givenName
    keys = [Contacts.CNContactGivenNameKey, Contacts.CNContactIdentifierKey]
    request = Contacts.CNContactFetchRequest.alloc().initWithKeysToFetch_(keys)

    matching = []
    try:
        success, error = store.enumerateContactsWithFetchRequest_error_(request, None)
    except Exception:
        # pyobjc enumerates via a block; use unifiedContactsMatchingPredicate instead
        pass

    # Alternative: fetch all and filter
    all_containers = store.containersMatchingPredicate_error_(None, None)
    for container in all_containers[0] if all_containers[0] else []:
        predicate = Contacts.CNContact.predicateForContactsInContainerWithIdentifier_(
            container.identifier()
        )
        contacts, error = store.unifiedContactsMatchingPredicate_keysToFetch_error_(
            predicate, keys, None
        )
        if contacts:
            for contact in contacts:
                if contact.givenName().startswith(prefix):
                    matching.append(contact)

    if not matching:
        print(f"No contacts found with prefix '{prefix}'")
        return

    print(f"Found {len(matching)} contacts with prefix '{prefix}'")

    save_request = Contacts.CNSaveRequest.alloc().init()
    for contact in matching:
        mutable = contact.mutableCopy()
        save_request.deleteContact_(mutable)

    success, error = store.executeSaveRequest_error_(save_request, None)
    if success:
        print(f"Deleted {len(matching)} contacts")
    else:
        print(f"Error deleting contacts: {error}")
        sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate or clean up test contacts for stress testing"
    )
    parser.add_argument(
        "--count", type=int, default=COUNT_DEFAULT,
        help=f"Number of contacts to generate (default: {COUNT_DEFAULT})",
    )
    parser.add_argument(
        "--output", type=str, default=None,
        help="Output .vcf file path (default: scripts/test_contacts.vcf)",
    )
    parser.add_argument(
        "--prefix", type=str, default=PREFIX_DEFAULT,
        help=f"Name prefix for test contacts (default: {PREFIX_DEFAULT})",
    )
    parser.add_argument(
        "--cleanup", action="store_true",
        help="Delete test contacts from macOS Contacts instead of generating",
    )
    args = parser.parse_args()

    if args.cleanup:
        cleanup_contacts(args.prefix)
    else:
        output = args.output or os.path.join(
            os.path.dirname(os.path.abspath(__file__)), "test_contacts.vcf"
        )
        generate_vcf_file(args.count, args.prefix, output)


if __name__ == "__main__":
    main()
