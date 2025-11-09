/*
 * Simple Parser Example - Target Code
 *
 * This is an example of vulnerable code that you might want to fuzz.
 * It contains intentional bugs for educational purposes.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>

#define MAX_SIZE 1024

typedef struct {
    char name[64];
    int value;
    char description[256];
} Record;

/*
 * Vulnerable function: Buffer overflow in name field
 * This demonstrates a classic stack buffer overflow
 */
int parse_record(unsigned char* data, size_t size, Record* rec) {
    if (!data || !rec || size < 4) {
        return -1;
    }

    // Read name length (vulnerable: no bounds check!)
    int name_len = data[0];

    // BUG: No check if name_len > sizeof(rec->name)
    memcpy(rec->name, data + 1, name_len);
    rec->name[name_len] = '\0';

    // Read value
    if (size < name_len + 5) {
        return -1;
    }
    rec->value = *(int*)(data + name_len + 1);

    // Read description length
    int desc_len = data[name_len + 5];

    // BUG: Another buffer overflow possible here
    if (size >= name_len + desc_len + 6) {
        memcpy(rec->description, data + name_len + 6, desc_len);
        rec->description[desc_len] = '\0';
    }

    return 0;
}

/*
 * Safe version of the parser (for comparison)
 */
int parse_record_safe(unsigned char* data, size_t size, Record* rec) {
    if (!data || !rec || size < 4) {
        return -1;
    }

    // Read name length with bounds check
    int name_len = data[0];
    if (name_len >= sizeof(rec->name)) {
        name_len = sizeof(rec->name) - 1;
    }

    memcpy(rec->name, data + 1, name_len);
    rec->name[name_len] = '\0';

    // Read value
    if (size < name_len + 5) {
        return -1;
    }
    rec->value = *(int*)(data + name_len + 1);

    // Read description length with bounds check
    int desc_len = data[name_len + 5];
    if (desc_len >= sizeof(rec->description)) {
        desc_len = sizeof(rec->description) - 1;
    }

    if (size >= name_len + desc_len + 6) {
        memcpy(rec->description, data + name_len + 6, desc_len);
        rec->description[desc_len] = '\0';
    }

    return 0;
}

/*
 * Parse a file containing multiple records
 */
int parse_file(const char* filename) {
    FILE* f = fopen(filename, "rb");
    if (!f) {
        return -1;
    }

    // Read file into buffer
    unsigned char buffer[MAX_SIZE];
    size_t size = fread(buffer, 1, sizeof(buffer), f);
    fclose(f);

    if (size == 0) {
        return -1;
    }

    // Parse each record
    Record rec;
    int offset = 0;

    while (offset < size) {
        // Check for end marker
        if (buffer[offset] == 0xFF) {
            break;
        }

        // Parse one record
        int result = parse_record(buffer + offset, size - offset, &rec);
        if (result != 0) {
            break;
        }

        // Debug output
        #ifdef DEBUG
        printf("Record: name=%s, value=%d, desc=%s\n",
               rec.name, rec.value, rec.description);
        #endif

        // Move to next record (this calculation could also overflow!)
        offset += buffer[offset] + 6 + buffer[offset + buffer[offset] + 5];
    }

    return 0;
}

/*
 * Main function for standalone testing
 */
#ifndef FUZZING_HARNESS
int main(int argc, char** argv) {
    if (argc < 2) {
        printf("Usage: %s <input_file>\n", argv[0]);
        printf("Example parser with intentional vulnerabilities for fuzzing\n");
        return 1;
    }

    printf("Parsing: %s\n", argv[1]);

    int result = parse_file(argv[1]);

    if (result == 0) {
        printf("Parsing successful\n");
    } else {
        printf("Parsing failed\n");
    }

    return result;
}
#endif
