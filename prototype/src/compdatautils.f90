! Functions and subroutines for accessing the datadb array in compdatadb.f90
! Specifically, to retrieve the BaseData struct for a specific fluid, and the VariantData struct for a
! Specific fluid and parameter reference
module compdatautils

use compdata_mod, only : CompData, VariantData, BaseData
use compdatadb, only : get_compdata, datadb_len, str_eq
implicit none

private
public :: get_base_data, get_variant_compdata

contains

! Get the BaseData struct corresponding to a specific fluid
function get_base_data(ident) result(bdata)
    character(len=10), intent(in) :: ident
    type(BaseData) :: bdata
    type(CompData) :: cdata

    call get_compdata(ident, cdata)
    bdata = cdata%base
end function get_base_data

! Get the VariantData struct corresponding to a specific fluid and parameter reference
function get_variant_compdata(ident, ref) result(data)
    character(len=10), intent(in) :: ident
    character(len=10), intent(in) :: ref
    type(VariantData) :: data

    type(CompData) :: cdata
    integer :: i

    call get_compdata(ident, cdata)

    print*, "Searching for ref : ", ref
    do i = 1, size(cdata%VariantDataDb)
        print*, "Checking : ", cdata%VariantDataDb(i)%ref
        if (str_eq(ref, cdata%VariantDataDb(i)%ref)) then
            data = cdata%VariantDataDb(i)
            return
        endif
    enddo

    print*, "No data found for ", ident, ", ref : ", ref
    error stop
end function get_variant_compdata

end module compdatautils