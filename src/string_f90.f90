module string_f90
  use, intrinsic :: iso_c_binding
  use :: t_heap_string_mod
  use :: t_string_pointer_mod
  implicit none


  private

  !* Specialty C operators.
  public :: string_from_c
  ! public :: string_from_c_with_length_goal
  public :: into_c_string

  !* Casting to/from string.
  public :: int_to_string
  public :: int64_to_string
  public :: f32_to_string
  public :: f64_to_string
  public :: bool_to_string
  public :: string_to_int
  public :: string_to_int64

  !* String manipulation.
  !* Will always generate a new string treating the original as immutable.
  public :: string_copy_pointer_to_pointer
  public :: string_get_file_name
  public :: string_remove_file_name_from_path
  public :: string_remove_file_extension
  public :: string_get_file_extension
  public :: string_cut_first
  public :: string_cut_last
  public :: string_cut_all
  public :: string_trim_white_space
  public :: string_trim_null_terminator
  public :: string_get_right_of_character
  public :: string_get_left_of_character
  public :: character_array_to_string_pointer

  !* String querying.
  public :: string_get_non_space_characters
  public :: string_starts_with
  public :: string_ends_with
  public :: string_contains_character
  public :: string_contains_substring


  !? Pass through types.
  public :: heap_string
  public :: string_pointer


  interface


    !? Internal only.
    function internal_c_strlen(c_str_ptr) result(length) bind(c, name = "strlen")
      use, intrinsic :: iso_c_binding
      implicit none

      type(c_ptr), intent(in), value :: c_str_ptr
      integer(c_size_t) :: length
    end function internal_c_strlen


  end interface


contains


!* SPECIALTY C OPERATORS. =================================================================================


  !* Dump a raw Fortran string pointer into a string.
  !* Returns the new string.
  function convert_c_string_pointer_to_string(length, input_pointer) result(output_string)
    use, intrinsic :: iso_c_binding
    implicit none

    character(len = 1, kind = c_char), dimension(:), pointer :: input_pointer
    character(len = :, kind = c_char), allocatable :: output_string
    ! Start off with the pointer width.
    integer(c_int) :: i, length

    ! Now allocate what is needed into the output string.
    allocate(character(len = length, kind = c_char) :: output_string)

    ! Now copy over each character.
    do i = 1, length
      output_string(i:i) = input_pointer(i)
    end do
  end function convert_c_string_pointer_to_string





  !* Convert a C str into a Fortran string pointer.
  function string_from_c(c_str_ptr) result(fortran_string_pointer)
    implicit none

    type(c_ptr), intent(in), value :: c_str_ptr
    character(len = :, kind = c_char), pointer :: fortran_string_pointer
    integer(c_size_t) :: str_length

    str_length = internal_c_strlen(c_str_ptr)

    call raw_c_str_to_fortran_string_cast(c_str_ptr, fortran_string_pointer, str_length)
  end function string_from_c


  !? This is using Fortran intrinsics to force a cast from C str to Fortran string.
  !! This should NEVER be exposed outside of this module.
  subroutine raw_c_str_to_fortran_string_cast(c_str_ptr, fortran_string_pointer, str_length)
    implicit none

    type(c_ptr), intent(in), value :: c_str_ptr
    integer(c_size_t), intent(in), value :: str_length
    character(len = :, kind = c_char), intent(inout), pointer :: fortran_string_pointer
    character(len = str_length, kind = c_char), pointer :: black_magic

    call c_f_pointer(c_str_ptr, black_magic)

    fortran_string_pointer => black_magic
  end subroutine raw_c_str_to_fortran_string_cast



  !* Use this to convert C str ptr into Fortran strings.
  !! DO NOT USE THIS
  !! This is a major hackjob.
  function string_from_c_with_length_goal(c_string_pointer, string_length) result(fortran_string)
    use, intrinsic :: iso_c_binding
    implicit none

    type(c_ptr), intent(in), value :: c_string_pointer
    character(len = 1, kind = c_char), dimension(:), pointer :: fortran_string_pointer
    character(len = :, kind = c_char), allocatable :: fortran_string
    integer(c_int) :: string_length, found_string_length
    integer(c_int) :: i

    ! Starts off as 0
    found_string_length = 0

    ! We must ensure that we are not converting a null pointer.
    if (.not. c_associated(c_string_pointer)) then
      fortran_string = ""
    else
      !? It seems that everything is okay, we will proceed.
      call c_f_pointer(c_string_pointer, fortran_string_pointer, [string_length])

      fortran_string = convert_c_string_pointer_to_string(string_length, fortran_string_pointer)

      fortran_string(string_length:string_length) = achar(0)

      ! Let's find the null terminator.
      do i = 1,string_length
        ! print*,fortran_raw_string(i)
        if (fortran_string(i:i) == achar(0)) then
          found_string_length = i - 1
          exit
        end if
      end do

      ! If the length is 0, we literally cannot do anything, so give up.
      if (found_string_length > 0) then
        ! Trim the string.
        fortran_string = fortran_string(1:found_string_length)
      else
        fortran_string = ""
      end if
    end if
  end function string_from_c_with_length_goal


  ! Convert a regular Fortran string into a null terminated C string.
  function into_c_string(input) result(output)
    implicit none

    character(len = *, kind = c_char) :: input
    character(len = :, kind = c_char), allocatable :: output

    ! Simply shove that string into the allocated string and null terminate it.
    !? This seems to automatically allocate so don't allocate for no reason.
    output = input//achar(0)
  end function into_c_string


!* CASTING TO/FROM STRING. =================================================================================


  ! Convert an integer into an allocated string.
  function int_to_string(i) result(output)
    implicit none

    integer(c_int) :: i
    character(len = :, kind = c_char), allocatable :: output

    ! If the number is any bigger than this, wat.
    allocate(character(11) :: output)
    write(output, "(i11)") i

    ! Now we shift the whole thing left and trim it to fit.
    output = trim(adjustl(output))
  end function int_to_string


  ! Convert an int64 into an allocated string.
  function int64_to_string(i) result(output)
    implicit none

    integer(c_int64_t) :: i
    character(len = :, kind = c_char), allocatable :: output

    ! If the number is any bigger than this, wat.
    allocate(character(20) :: output)
    write(output, "(i20)") i

    ! Now we shift the whole thing left and trim it to fit.
    output = trim(adjustl(output))
  end function int64_to_string


  !* Convert an f32 to a string.
  function f32_to_string(i) result(output)
    implicit none

    real(c_float), intent(in), value :: i
    character(len = :, kind = c_char), allocatable :: output

    allocate(character(len = 64) :: output)

    ! This is going to act weird cause of the mantissa, too bad.
    write(output, "(f0.7)") i

    output = string_trim_white_space(output)

    if (string_starts_with(output, ".")) then
      output = "0"//output
    else if (string_starts_with(output, "-.")) then
      output = "-0"//output(2:len(output))
    end if
  end function f32_to_string


  !* Convert an f64 to a string.
  function f64_to_string(i) result(output)
    implicit none

    real(c_double), intent(in), value :: i
    character(len = :, kind = c_char), allocatable :: output

    allocate(character(len = 64) :: output)

    ! This is going to act weird cause of the mantissa, too bad.
    write(output, "(f0.7)") i

    output = string_trim_white_space(output)

    if (string_starts_with(output, ".")) then
      output = "0"//output
    else if (string_starts_with(output, "-.")) then
      output = "-0"//output(2:len(output))
    end if
  end function f64_to_string


  ! Convert a logical into an allocated string.
  !* Allocatable will deallocate once the memory goes out of scope.
  function bool_to_string(bool) result(output)
    implicit none

    logical :: bool
    character(len = :), allocatable :: output

    allocate(character(5) :: output)

    ! Simply write true or false into the string.
    if (bool) then
      write(output, "(A)") "true"
    else
      write(output, "(A)") "false"
    end if

    ! Now we shift the whole thing left and trim it to fit.
    output = trim(adjustl(output))
  end function bool_to_string


  !* Convert a string to an int.
  function string_to_int(input_string) result(int)
    implicit none

    character(len = *, kind = c_char), intent(in) :: input_string
    integer(c_int) :: int

    int = 0

    ! Don't parse empty strings.
    if (input_string == "") then
      return
    end if

    read(input_string, *) int
  end function string_to_int


  !* Convert a string to an int.
  function string_to_int64(input_string) result(int64)
    implicit none

    character(len = *, kind = c_char), intent(in) :: input_string
    integer(kind = c_int64_t) :: int64

    int64 = 0

    ! Don't parse empty strings.
    if (input_string == "") then
      return
    end if

    read(input_string, *) int64
  end function string_to_int64


!* STRING MANIPULATION. =================================================================================


  !* Copy a string pointer into an UNALLOCATED string pointer.
  !* This ALLOCATES [to].
  subroutine string_copy_pointer_to_pointer(from, to)
    implicit none

    character(len = :, kind = c_char), intent(in), pointer :: from
    character(len = :, kind = c_char), intent(inout), pointer :: to
    integer(c_int) :: str_length

    str_length = len(from)

    if (.not. associated(from)) then
      error stop "[String] Error: from is not allocated."
    end if

    if (associated(to)) then
      error stop "[String] Error: to is already allocated."
    end if

    allocate(character(len = str_length, kind = c_char) :: to)

    to(1:str_length) = from(1:str_length)
  end subroutine string_copy_pointer_to_pointer


  !* Get a file name string from a string that is a path.
  function string_get_file_name(input_string) result(resulting_name_of_file)
    use, intrinsic :: iso_c_binding, only: c_char
    implicit none

    character(len = *, kind = c_char), intent(in) :: input_string
    character(len = :, kind = c_char), allocatable :: resulting_name_of_file
    integer(c_int) :: i, length_of_string

    i = index(input_string, "/", back = .true.)

    ! This probably isn't a path.
    if (i == 0) then
      print"(A)", achar(27)//"[38;2;255;128;0m[String] Warning: Could not extract file name from directory."//achar(27)//"[m"
      resulting_name_of_file = ""
      return
    end if

    length_of_string = len(input_string)

    ! This is a folder.
    if (i == length_of_string) then
      print"(A)", achar(27)//"[38;2;255;128;0m[String] Warning: Tried to get file name of folder."//achar(27)//"[m"
      resulting_name_of_file = ""
      return
    end if

    ! So this is a file. Let's now get it
    resulting_name_of_file = input_string(i + 1:length_of_string)
  end function string_get_file_name


  !* Can convert [./test/cool.png] into [./test/]
  function string_remove_file_name_from_path(input_file_name) result(file_name_without_extension)
    implicit none

    character(len = *, kind = c_char), intent(in) :: input_file_name
    character(len = :), allocatable :: file_name_without_extension
    integer(c_int) :: i

    i = index(input_file_name, "/", back = .true.)

    if (i == 0) then
      print"(A)", achar(27)//"[38;2;255;128;0m[String] Warning: Tried to remove file name off string that's not a file path."//achar(27)//"[m"
      file_name_without_extension = ""
      return
    end if

    file_name_without_extension = input_file_name(1:i)
  end function string_remove_file_name_from_path


  !* Convert something like "test.png" into "test"
  function string_remove_file_extension(input_file_name) result(file_name_without_extension)
    implicit none

    character(len = *, kind = c_char), intent(in) :: input_file_name
    character(len = :), allocatable :: file_name_without_extension
    integer(c_int) :: i

    i = index(input_file_name, ".", back = .true.)

    if (i == 0) then
      print"(A)", achar(27)//"[38;2;255;128;0m[String] Warning: Tried to remove file extension off string that's not a file name."//achar(27)//"[m"
      file_name_without_extension = ""
      return
    end if

    file_name_without_extension = input_file_name(1:i - 1)
  end function string_remove_file_extension


  !* Get a file extension from a string.
  !* If it has no extension, this returns "".
  function string_get_file_extension(input_file_name) result(extension)
    implicit none

    character(len = *, kind = c_char), intent(in) :: input_file_name
    character(len = :, kind = c_char), allocatable :: extension
    integer(c_int) :: i, string_length

    i = index(input_file_name, ".", back = .true.)

    ! Has no extension.
    if (i == 0) then
      extension = ""
      return
    end if

    ! Move the index past the [.]
    i = i + 1

    string_length = len(input_file_name)

    ! Probably a sentence?
    if (i >= string_length) then
      extension = ""
      return
    end if

    extension = input_file_name(i:string_length)
  end function string_get_file_extension


  !* Cut the first instance of a substring out of a string. Searches left to right.
  function string_cut_first(input_string, sub_string) result(cut_string)
    implicit none

    character(len = *, kind = c_char), intent(in) :: input_string, sub_string
    character(len = :, kind = c_char), allocatable :: cut_string
    integer(c_int) :: found_index, sub_string_width, inner_left, inner_right, outer_left, outer_right


    ! Starts off as the input.
    cut_string = input_string

    ! If blank, return.
    if (input_string == "") then
      return
    end if

    ! If a character, there's no way to really work with that.

    found_index = index(input_string, sub_string)

    ! Not found.
    if (found_index == 0) then
      return
    end if

    sub_string_width = len(sub_string)

    ! Left side of the target.
    inner_left = 1
    inner_right = found_index - 1

    ! Right side of the target.
    outer_left = found_index + sub_string_width
    outer_right = len(input_string)

    ! Now we just concatenate the beginning and ending together.
    cut_string = input_string(inner_left:inner_right)//input_string(outer_left:outer_right)
  end function string_cut_first


  !* Cut the last instance of a substring out of a string. Searches right to left.
  function string_cut_last(input_string, sub_string) result(cut_string)
    implicit none

    character(len = *, kind = c_char), intent(in) :: input_string, sub_string
    character(len = :, kind = c_char), allocatable :: cut_string
    integer(c_int) :: found_index, sub_string_width, inner_left, inner_right, outer_left, outer_right


    ! Starts off as the input.
    cut_string = input_string

    ! If blank, return.
    if (input_string == "") then
      return
    end if

    ! If a character, there's no way to really work with that.

    found_index = index(input_string, sub_string, back = .true.)

    ! Not found.
    if (found_index == 0) then
      return
    end if

    sub_string_width = len(sub_string)

    ! Left side of the target.
    inner_left = 1
    inner_right = found_index - 1

    ! Right side of the target.
    outer_left = found_index + sub_string_width
    outer_right = len(input_string)

    ! Now we just concatenate the beginning and ending together.
    cut_string = input_string(inner_left:inner_right)//input_string(outer_left:outer_right)
  end function string_cut_last


  !* Cut all instances of a substring out of a string.
  function string_cut_all(input_string, sub_string) result(cut_string)
    implicit none

    character(len = *, kind = c_char), intent(in) :: input_string, sub_string
    character(len = :, kind = c_char), allocatable :: old_string, cut_string

    old_string = input_string
    cut_string = input_string

    do while(.true.)
      !? If you want to see this happen in real time, turn this on. It's neat. :)
      ! print*,"old: ["//old_string//"]"

      cut_string = string_cut_first(cut_string, sub_string)

      ! The strings are now equal, it failed to cut.
      if (cut_string == old_string) then
        exit
      end if

      ! Save this state for the next cycle.
      old_string = cut_string
    end do
  end function string_cut_all


  !* Strip leading and trailing white space off a string.
  function string_trim_white_space(input_string) result(output_string)
    implicit none

    character(len = *, kind = c_char), intent(in) :: input_string
    character(len = :, kind = c_char), allocatable :: output_string

    ! This is kind of like how you remove bits in a bit shift, but for strings.
    output_string = trim(adjustl(input_string))
  end function string_trim_white_space


  !* Strip the null terminator (\0) off a string when C acts up.
  function string_trim_null_terminator(input_string) result(output_string)
    implicit none

    character(len = *, kind = c_char), intent(in) :: input_string
    character(len = :, kind = c_char), allocatable :: output_string
    integer(c_int) :: length, i, found_index

    length = len(input_string)
    found_index = -1

    do i = 1,length
      if (input_string(i:i) == achar(0)) then
        found_index = i - 1
        exit
      end if
    end do

    if (found_index == -1) then
      output_string = input_string
      return
    end if

    output_string = input_string(1:found_index)
  end function string_trim_null_terminator


  !* This helper function is mainly made for parsing conf files.
  !* It will remove all surrounding space.
  !* Will return "" if can't parse.
  !* Example:
  !* test = blah
  !* return: [blah]
  function string_get_right_of_character(input_string, char) result(output_string)
    implicit none

    character(len = *, kind = c_char), intent(in) :: input_string
    character(len = 1, kind = c_char), intent(in) :: char
    character(len = :, kind = c_char), allocatable :: output_string
    integer(c_int) :: found_index, input_length

    found_index = index(input_string, char)

    ! No character found.
    if (found_index == 0) then
      output_string = ""
      return
    end if

    input_length = len(input_string)

    ! Shift it to the right of the found character index.
    found_index = found_index + 1

    ! Out of bounds.
    if (found_index > input_length) then
      output_string = ""
      return
    end if

    ! Then process it.
    output_string = input_string(found_index:input_length)
    output_string = string_trim_white_space(output_string)
  end function string_get_right_of_character


  !* This helper function is mainly made for parsing conf files.
  !* It will remove all surrounding space.
  !* Will return "" if can't parse.
  !* Example:
  !* test = blah
  !* return: [test]
  function string_get_left_of_character(input_string, char) result(output_string)
    implicit none

    character(len = *, kind = c_char), intent(in) :: input_string
    character(len = 1, kind = c_char), intent(in) :: char
    character(len = :, kind = c_char), allocatable :: output_string
    integer(c_int) :: found_index

    found_index = index(input_string, char)

    ! No character found.
    if (found_index == 0) then
      output_string = ""
      return
    end if

    ! Shift it to the left of the found character index.
    found_index = found_index - 1

    ! Out of bounds.
    if (found_index <= 0) then
      output_string = ""
      return
    end if

    ! Then process it.
    output_string = input_string(1:found_index)
    output_string = string_trim_white_space(output_string)
  end function string_get_left_of_character


  !* Convert [character, dimension(:)] to [character(:)].
  !! This function assumed null termination on the string.
  function character_array_to_string_pointer(char_array) result(str)
    implicit none

    character(len = 1, kind = c_char), dimension(:), intent(in) :: char_array
    character(len = :, kind = c_char), pointer :: str
    integer(c_int32_t) :: i, string_length

    do i = 1,size(char_array)
      if (char_array(i) == achar(0)) then
        string_length = i - 1
        exit
      end if
    end do

    allocate(character(len = string_length, kind = c_char) :: str)

    do i = 1,string_length
      str(i:i) = char_array(i)
    end do
  end function character_array_to_string_pointer


!* STRING QUERYING. =================================================================================


  !* Get the count of non space characters in a string.
  !* So "a b c" is a count of 3.
  function string_get_non_space_characters(input_string) result(character_count)
    implicit none

    character(len = *, kind = c_char), intent(in) :: input_string
    integer(c_int) :: character_count, i

    character_count = 0

    ! Yeah, we're literally just counting the non space characters.
    do i = 1,len(input_string)
      if (input_string(i:i) == " ") then
        cycle
      end if
      character_count = character_count + 1
    end do
  end function string_get_non_space_characters


  !* Check if a string starts with a sub string.
  function string_starts_with(input_string, sub_string) result(starts_with)
    implicit none

    character(len = *, kind = c_char), intent(in) :: input_string, sub_string
    logical :: starts_with

    starts_with = .false.

    ! Blank.
    if (sub_string == "" .or. input_string == "") then
      return
    end if

    starts_with = index(input_string, sub_string) == 1
  end function string_starts_with


  !* Check if a string ends with a sub string.
  function string_ends_with(input_string, sub_string) result(ends_with)
    implicit none

    character(len = *, kind = c_char), intent(in) :: input_string, sub_string
    logical :: ends_with
    integer(c_int) :: input_length, sub_string_length, found_index

    ends_with = .false.

    ! Blank.
    if (sub_string == "" .or. input_string == "") then
      return
    end if

    found_index = index(input_string, sub_string, back = .true.)

    ! Not found.
    if (found_index == 0) then
      return
    end if

    input_length = len(input_string)
    sub_string_length = len(sub_string)

    ! We can simply check if adding the found index with the size
    ! of the substring matches the input length.
    ! Subtract 1 to push it back to 0 index.
    ! [hi there] check [re]
    ! found at [7], sub length: [2], in length: [8]
    ! [[7 + 2] - 1] == 8 == .true.
    ends_with = (found_index + sub_string_length) - 1 == input_length
  end function string_ends_with


  !* Check if a string has a character.
  function string_contains_character(input_string, char) result(has_char)
    implicit none

    character(len = *, kind = c_char), intent(in) :: input_string
    character(len = 1, kind = c_char), intent(in) :: char
    logical :: has_char

    has_char = index(input_string, char) /= 0
  end function string_contains_character


  !* Check if a string has a character.
  function string_contains_substring(input_string, sub_string) result(has_sub_string)
    implicit none

    character(len = *, kind = c_char), intent(in) :: input_string, sub_string
    logical :: has_sub_string

    has_sub_string = index(input_string, sub_string) /= 0
  end function string_contains_substring


end module string_f90
