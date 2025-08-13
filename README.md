## Hardclone Live 1.0.0  

First stable release of **Hardclone Live** – a complete live environment for disk cloning, imaging, and recovery.  

---

### 📥 Download  

[![Download ISO](https://img.shields.io/badge/Download-ISO-blue?style=for-the-badge&logo=google-drive)](https://drive.google.com/file/d/1NnssTo7gUVJM6VxCqbfKNl3sb6-ysn9x/view?usp=sharing)
[![Checksums](https://img.shields.io/badge/Checksums-md5%20%7C%20sha512-green?style=for-the-badge)](https://github.com/yourusername/yourrepo#checksums)  

- **ISO image (~2.8 GB)**: [Google Drive link](https://drive.google.com/file/d/1NnssTo7gUVJM6VxCqbfKNl3sb6-ysn9x/view?usp=sharing)  
- **MD5 checksum:** [Download `.md5`](https://drive.google.com/file/d/1lW4BBbC7_z-KmNyczitLrCbeGP3o5_Gf/view?usp=sharing)  
- **SHA512 checksum:** [Download `.sha512`](https://drive.google.com/file/d/1CjzKR5ytDKhSs2IpvC_XpOK4Z_o5AL5n/view?usp=sharing)  

---

### 🔑 Checksums  
```

MD5:     f815d98deacbdb9ac0ff2d8c5a22afd1
SHA512:  47dc7d6d36d4539d13b10b080ea55956ebd60c71c10a9647ef6fdcd09330f8c194b7a4298ef5d45449010b8a27eb473041ad2e4a3083858d270228ebf17e172d

````

---

### 🛠 How to use the ISO  

#### 💻 Windows  
1. Download the `.iso` file from the link above.  
2. Download and run [Rufus](https://rufus.ie/).  
3. Select the downloaded ISO and write it to a USB drive (min. 4 GB).  
4. Boot your computer from the prepared USB drive.  

#### 🐧 Linux / macOS  
1. Download the `.iso` file.  
2. Verify the checksums:  
   ```bash
   md5sum snapshot-20250812_2135.iso
   sha512sum snapshot-20250812_2135.iso
   ```

3. Write the ISO to a USB drive (replace `/dev/sdX` with the correct device):

   ```bash
   sudo dd if=snapshot-20250812_2135.iso of=/dev/sdX bs=4M status=progress oflag=sync
   ```

---

💡 **Tip:** You can also run the ISO directly in a virtual machine (VirtualBox, QEMU, VMware, etc.) by selecting it as the boot image.
