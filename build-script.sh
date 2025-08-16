Checking boot files...
./syslinux/isolinux.bin
./boot/grub/efi.img
./live/mt86+x32.efi
./live/mt86+x64.efi
./live/ipxe.efi
./EFI/boot/bootx64.efi
./EFI/boot/grubx64.efi
Found isolinux.bin at: ./syslinux/isolinux.bin
Found EFI image at: ./boot/grub/efi.img
Creating new ISO...
xorriso 1.5.4 : RockRidge filesystem manipulator, libburnia project.

Drive current: -outdev 'stdio:../hardclone-live-20250816.iso'
Media current: stdio file, overwriteable
Media status : is blank
Media summary: 0 sessions, 0 data blocks, 0 data, 24.9g free
xorriso : WARNING : -volid text does not comply to ISO 9660 / ECMA 119 rules
Added to ISO image: directory '/'='/workspace/clonezilla-custom/iso-extract'
xorriso : UPDATE :     335 files added in 1 seconds
libisofs: FAILURE : Cannot find directory for El Torito boot catalog in ISO image: '/isolinux'
libisofs: FAILURE : A requested node does not exist
xorriso : FAILURE : Could not attach El-Torito boot image to ISO 9660 image
xorriso : UPDATE :     335 files added in 1 seconds
xorriso : aborting : -abort_on 'FAILURE' encountered 'FAILURE'
Error: Process completed with exit code 5.
