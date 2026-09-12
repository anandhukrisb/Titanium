#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef uint8_t boolean;
#define true 1
#define false 0

typedef struct{

    uint8_t BootJumpInstruction[3];
    uint8_t OemIdentifier[8];
    uint16_t BytesPerSector;
    uint8_t SectorPerCluster;
    uint16_t ReservedSectors;
    uint8_t FatCount;
    uint16_t DirEntryCount;
    uint16_t TotalSectors;
    uint8_t MediaDescriptorType;
    uint16_t SectorsPerFat;
    uint16_t SectorPerTrack;
    uint16_t Heads;
    uint32_t HiddenSectors;
    uint32_t LargeSectorCount;
    
    // extended boot record

    uint8_t DriveNumber;
    uint8_t _reserved;
    uint8_t Signature;
    uint32_t VolumeId;
    uint8_t VolumeLabel[11];
    uint8_t SystemId[8];


} __attribute__((packed)) BootSector;

typedef struct {
    uint8_t Name[11];
    uint8_t Attributes;
    uint8_t _Reserved;
    uint8_t CreatedTimeTenths;
    uint16_t CreationTime;
    uint16_t CreationDate;
    uint16_t AccessedDate;
    uint16_t FirstClusterHigh;
    uint16_t ModifiedTime;
    uint16_t ModifiedDate;
    uint16_t FirstClusterLow;
    uint32_t Size;
} __attribute__((packed)) DirectoryEntry;

BootSector g_BootSector;
uint8_t* g_fat = NULL;
DirectoryEntry* g_RootDirectory = NULL;
uint32_t g_RootDirectoryEnd;

boolean readBootSector(FILE* disk){

    return fread(&g_BootSector, sizeof(g_BootSector), 1, disk) > 0;

}

boolean readSectors(FILE* disk, uint32_t lba, uint32_t count, void* bufferOut) {

    boolean ok = true;
    ok = ok && (fseek(disk, lba * g_BootSector.BytesPerSector, SEEK_SET) == 0);
    ok = ok && (fread(bufferOut, g_BootSector.BytesPerSector, count, disk) == count);

    return ok;

}

boolean readFat(FILE* disk) {
    g_fat = (uint8_t*) malloc(g_BootSector.SectorsPerFat * g_BootSector.BytesPerSector);
    return readSectors(disk, g_BootSector.ReservedSectors, g_BootSector.SectorsPerFat, g_fat);
}

boolean readRootDirectory(FILE* disk) {

    uint32_t lba = g_BootSector.ReservedSectors + g_BootSector.SectorsPerFat * g_BootSector.FatCount;
    uint32_t size = sizeof(DirectoryEntry) * g_BootSector.DirEntryCount;
    uint32_t sectors = (size / g_BootSector.BytesPerSector);

    if(size % g_BootSector.BytesPerSector > 0)
        sectors++;
    
    g_RootDirectoryEnd = lba + sectors;
    g_RootDirectory = (DirectoryEntry*) malloc(sectors * g_BootSector.BytesPerSector);

    return readSectors(disk, lba, sectors, g_RootDirectory);

}

DirectoryEntry* findFile(const char* name) {

    for(uint32_t i = 0; i < g_BootSector.DirEntryCount; i++) {
        if(memcmp(name, g_RootDirectory[i].Name, 11) == 0) {
            return &g_RootDirectory[i];
        }
    }

    return NULL;

}

boolean readFile(DirectoryEntry* fileEntry, FILE* disk, uint8_t outputBuffer) {

    boolean ok = true;
    uint16_t currentCluster = fileEntry -> FirstClusterLow;
    
    do {
        uint32_t lba = g_RootDirectoryEnd + (currentCluster - 2) * g_BootSector.SectorPerCluster;
        ok = ok && readSectors(disk, lba, g_BootSector.SectorPerCluster, outputBuffer);
        outputBuffer += g_BootSector.SectorPerCluster * g_BootSector.BytesPerSector;

    }while(ok);

    return ok;

}

int main(int argc, char** argv) {

    if(argc < 3) {
        printf("Syntax: %c <disk_image> <file_name>", argv[0]);
        return -1;
    }

    FILE* disk = fopen(argv[1], "rb");
    if(!disk) {
        fprintf(stderr, "Cannot open disk image %s", argv[1]);
        return -1;
    }

    if(!readBootSector(disk)) {
        fprintf(stderr, "Could not read boot sector!\n");
        return -2;
    }

    if(!readFat(disk)) {
        fprintf(stderr, "Could not read FAT!\n");
        free(g_fat);
        return -3;
    }

    if(!readRootDirectory(disk)) {
        fprintf(stderr, "Could not read Root Directory!\n");
        free(g_fat);
        free(g_RootDirectory);
        return -4;
    }

    DirectoryEntry* fileEntry = findFile(argv[2]);

    if(!fileEntry) {
        fprintf(stderr, "Could not read File %s\n", argv[2]);
        free(g_fat);
        free(g_RootDirectory);
        return -5;
    }

    free(g_fat);
    free(g_RootDirectory);

    return 0;

}