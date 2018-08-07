REDOX_ROOT=.
SHELL=/bin/bash

default: run

.PHONY: clean

clean:
	rm -rf build
	rm -rf target
	rm Cargo.lock
	xargo clean

run_iso: build/os.iso
	qemu-system-x86_64 -cdrom build/os.iso

run1: build/harddrive.bin build/extra.qcow2
	SDL_VIDEO_X11_DGAMOUSE=0 qemu-system-x86_64 -serial mon:stdio -d cpu_reset -d guest_errors -smp 4 -m 2048 -machine q35 -net nic,model=e1000 -net user -net dump,file=build/network.pcap -enable-kvm -device nec-usb-xhci,id=xhci -device usb-tablet,bus=xhci.0 -s \
    -drive file=build/harddrive.bin,format=raw

run: build/harddrive.bin build/extra.qcow2
	SDL_VIDEO_X11_DGAMOUSE=0 qemu-system-x86_64 -serial mon:stdio -d cpu_reset -d guest_errors -smp 4 -m 2048 -machine q35 -net nic,model=e1000 -net user -net dump,file=build/network.pcap -device nec-usb-xhci,id=xhci -device usb-tablet,bus=xhci.0 -s \
    -drive file=build/harddrive.bin,format=raw \
    -drive file=build/extra.qcow2

debug: build/harddrive.bin build/extra.qcow2
	qemu-system-x86_64 -serial mon:stdio -drive file=build/harddrive.bin,format=raw -drive file=build/extra.qcow2 -s -S
debug1:
	SDL_VIDEO_X11_DGAMOUSE=0 qemu-system-x86_64 -serial mon:stdio -d cpu_reset -d guest_errors -smp 4 -m 2048 -machine q35 -net nic,model=e1000 -net user -net dump,file=build/network.pcap -device nec-usb-xhci,id=xhci -enable-kvm -cpu host -device usb-tablet,bus=xhci.0 -s -S\
    -drive file=build/harddrive.bin,format=raw \
    -drive file=build/extra.qcow2

build/extra.qcow2:
	qemu-img create -f qcow2 $@ 1G
build/ice.txt:
	echo "Burning 'em, if you ain't quick and nimble. I go crazy when I hear a cymbal." > build/ice.txt

build/fat32.img: build/ice.txt
	dd if=/dev/zero of=build/fat32.img bs=512 count=1000000
	mkfs -t fat -F 32 build/fat32.img
	mcopy -i build/fat32.img build/ice.txt ::.
	mcopy -i build/fat32.img kernel.dat ::.
	mcopy -i build/fat32.img build/kernel.bin ::.
build/os.iso: build/kernel.bin kernel/grub.cfg
	mkdir -p build/isofiles/boot/grub
	cp kernel/grub.cfg build/isofiles/boot/grub
	cp build/kernel.bin build/isofiles/boot/
	grub2-mkrescue -o build/os.iso build/isofiles/

build/kernel.bin: kernel/linker.ld cargo
	ld --gc-sections -z max-page-size=0x1000 -o $@ -T kernel/linker.ld build/libredox_loader.a
	objcopy --strip-debug $@
build/real.bin:
	nasm -f bin -o build/real.bin bootloader/x86_64/real.asm

build/harddrive.bin: build/kernel.bin build/real.bin build/fat32.img
	nasm -f bin -o $@ -D ARCH_x86_64 -D KERNEL=build/kernel.bin -D REALSTUB=build/real.bin -D REDOXFS=filesystem.bin -D FAT32=build/fat32.img -ibuild/ -ibootloader/x86_64/ bootloader/x86_64/disk.asm
	dd if=/dev/zero bs=512 count=18126 >> $@ 

cargo:
	mkdir -p build
	cargo update -p linked_list_allocator --precise 0.6.2
	TARGET=. RUST_TARGET_PATH=$(shell pwd) xargo build --release --target x86_64-redox_loader
	cp target/x86_64-redox_loader/release/libredox_loader.a build/libredox_loader.a
