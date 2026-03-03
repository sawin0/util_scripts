def remove_duplicate_emails(input_file, output_file):
    try:
        # Read all emails from file
        with open(input_file, 'r') as f:
            emails = f.readlines()

        # Remove whitespace and duplicates
        unique_emails = set(email.strip() for email in emails if email.strip())

        # Sort emails (optional)
        unique_emails = sorted(unique_emails)

        # Write back to a new file
        with open(output_file, 'w') as f:
            for email in unique_emails:
                f.write(email + '\n')

        print(f"Duplicates removed! Clean file saved as: {output_file}")

    except FileNotFoundError:
        print("Input file not found!")
    except Exception as e:
        print(f"Error: {e}")


# Example usage
input_file = "emails.txt"
output_file = "cleaned_emails.txt"

remove_duplicate_emails(input_file, output_file)
