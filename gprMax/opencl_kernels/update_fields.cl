{#
// Update E-Field 

// Template Parameter :: 
//     common_header:
#}

#define INDEX2D_MAT(m, n) (m)*({{NY_MATCOEFFS}}) + (n)
#define INDEX2D_MATDISP(m, n) (m)*({{NY_MATDISPCOEFFS}}) + (n)
#define INDEX3D_FIELDS(i, j, k) (i)*({{NY_FIELDS}})*({{NZ_FIELDS}}) + (j)*({{NZ_FIELDS}}) + (k)
#define INDEX4D_ID(p, i, j, k) (p)*({{NX_ID}})*({{NY_ID}})*({{NZ_ID}}) + (i)*({{NY_ID}})*({{NZ_ID}}) + (j)*({{NZ_ID}}) + (k)
#define INDEX4D_T(p, i, j, k) (p)*({{NX_T}})*({{NY_T}})*({{NZ_T}}) + (i)*({{NY_T}})*({{NZ_T}}) + (j)*({{NZ_T}}) + (k)

// material update coefficients to be declared in constant memory
__constant {{REAL}} updatecoeffsE[{{N_updatecoeffsE}}] = 
{
    {% for i in updateEVal %}
    {{i}},
    {% endfor %}
};

__constant {{REAL}} updatecoeffsH[{{N_updatecoeffsH}}] = 
{
    {% for i in updateHVal %}
    {{i}},
    {% endfor %}
};

__kernel void update_e(int NX, int NY, int NZ, __global const unsigned int* restrict ID, __global {{REAL}} *Ex, __global {{REAL}} *Ey, __global {{REAL}} *Ez, __global const {{REAL}} * restrict Hx, __global const {{REAL}} * restrict Hy, __global const {{REAL}} * restrict Hz){
    // this function updates electric field values

    // Args:
    //     Nx, Ny, Nz : number of cells of the models domain
    //     ID, E, H : Access to ID and field component arrays

    // get the linear index corresponding to the current work item
    int idx = get_global_id(2) * get_global_size(0) * get_global_size(1) + get_global_id(1) * get_global_size(0) + get_global_id(0);

    // convert the linear index to subscripts for 3D field arrays
    int i = idx / ({{NY_FIELDS}} * {{NZ_FIELDS}});
    int j = (idx % ({{NY_FIELDS}}*{{NZ_FIELDS}})) / {{NZ_FIELDS}};
    int k = (idx % ({{NY_FIELDS}}*{{NZ_FIELDS}})) % {{NZ_FIELDS}};

    //convert the linear index to subscripts for 4D material ID arrays
    int i_ID = (idx%({{NX_ID}} * {{NY_ID}} * {{NZ_ID}})) / ({{NY_ID}} * {{NZ_ID}});
    int j_ID = ((idx%({{NX_ID}} * {{NY_ID}} * {{NZ_ID}})) % ({{NY_ID}} * {{NZ_ID}})) / {{NZ_ID}};
    int k_ID = ((idx%({{NX_ID}} * {{NY_ID}} * {{NZ_ID}})) % ({{NY_ID}} * {{NZ_ID}})) % {{NZ_ID}};

    // Ex component
    if ((NY != 1 || NZ != 1) && i >= 0 && i < NX && j > 0 && j < NY && k > 0 && k < NZ) {
        int materialEx = ID[INDEX4D_ID(0,i_ID,j_ID,k_ID)];
        Ex[INDEX3D_FIELDS(i,j,k)] = updatecoeffsE[INDEX2D_MAT(materialEx,0)] * Ex[INDEX3D_FIELDS(i,j,k)] + updatecoeffsE[INDEX2D_MAT(materialEx,2)] * (Hz[INDEX3D_FIELDS(i,j,k)] - Hz[INDEX3D_FIELDS(i,j-1,k)]) - updatecoeffsE[INDEX2D_MAT(materialEx,3)] * (Hy[INDEX3D_FIELDS(i,j,k)] - Hy[INDEX3D_FIELDS(i,j,k-1)]);
    }

    // Ey component
    if ((NX != 1 || NZ != 1) && i > 0 && i < NX && j >= 0 && j < NY && k > 0 && k < NZ) {
        int materialEy = ID[INDEX4D_ID(1,i_ID,j_ID,k_ID)];
        Ey[INDEX3D_FIELDS(i,j,k)] = updatecoeffsE[INDEX2D_MAT(materialEy,0)] * Ey[INDEX3D_FIELDS(i,j,k)] + updatecoeffsE[INDEX2D_MAT(materialEy,3)] * (Hx[INDEX3D_FIELDS(i,j,k)] - Hx[INDEX3D_FIELDS(i,j,k-1)]) - updatecoeffsE[INDEX2D_MAT(materialEy,1)] * (Hz[INDEX3D_FIELDS(i,j,k)] - Hz[INDEX3D_FIELDS(i-1,j,k)]);
    }

    // Ez component
    if ((NX != 1 || NY != 1) && i > 0 && i < NX && j > 0 && j < NY && k >= 0 && k < NZ) {
        int materialEz = ID[INDEX4D_ID(2,i_ID,j_ID,k_ID)];
        Ez[INDEX3D_FIELDS(i,j,k)] = updatecoeffsE[INDEX2D_MAT(materialEz,0)] * Ez[INDEX3D_FIELDS(i,j,k)] + updatecoeffsE[INDEX2D_MAT(materialEz,1)] * (Hy[INDEX3D_FIELDS(i,j,k)] - Hy[INDEX3D_FIELDS(i-1,j,k)]) - updatecoeffsE[INDEX2D_MAT(materialEz,2)] * (Hx[INDEX3D_FIELDS(i,j,k)] - Hx[INDEX3D_FIELDS(i,j-1,k)]);
    }
}

__kernel void update_h(int NX, int NY, int NZ, __global const unsigned int* restrict ID, __global {{REAL}} *Hx, __global {{REAL}} *Hy, __global {{REAL}} *Hz, __global const {{REAL}}* restrict Ex, __global const {{REAL}}* restrict Ey, __global const {{REAL}}* restrict Ez){
    // this function updates magnetic field values

    // Args:
    //     NX, NY, NZ : number of cells of the model domain
    //     ID, E, H : access to ID and field component arrays

    // obtain the linear index corresponding to the current work item
    int idx = get_global_id(0);

    // convert the linear index to subscripts to 3D field arrays
    int i = idx / ({{NY_FIELDS}} * {{NZ_FIELDS}});
    int j = (idx%({{NY_FIELDS}}*{{NZ_FIELDS}})) / {{NZ_FIELDS}};
    int k = (idx%({{NY_FIELDS}}*{{NZ_FIELDS}})) % {{NZ_FIELDS}};

    // convert the linear index to subscripts to 4D material ID arrays
    int i_ID = ( idx % ({{NX_ID}} * {{NY_ID}} * {{NZ_ID}})) / ({{NY_ID}} * {{NZ_ID}});
    int j_ID = (( idx % ({{NX_ID}} * {{NY_ID}} * {{NZ_ID}})) % ({{NY_ID}} * {{NZ_ID}})) / {{NZ_ID}};
    int k_ID = (( idx % ({{NX_ID}} * {{NY_ID}} * {{NZ_ID}})) % ({{NY_ID}} * {{NZ_ID}})) % {{NZ_ID}};

    // Hx component
    if (NX != 1 && i > 0 && i < NX && j >= 0 && j < NY && k >= 0 && k < NZ) {
        int materialHx = ID[INDEX4D_ID(3,i_ID,j_ID,k_ID)];
        Hx[INDEX3D_FIELDS(i,j,k)] = updatecoeffsH[INDEX2D_MAT(materialHx,0)] * Hx[INDEX3D_FIELDS(i,j,k)] - updatecoeffsH[INDEX2D_MAT(materialHx,2)] * (Ez[INDEX3D_FIELDS(i,j+1,k)] - Ez[INDEX3D_FIELDS(i,j,k)]) + updatecoeffsH[INDEX2D_MAT(materialHx,3)] * (Ey[INDEX3D_FIELDS(i,j,k+1)] - Ey[INDEX3D_FIELDS(i,j,k)]);
    }

    // Hy component
    if (NY != 1 && i >= 0 && i < NX && j > 0 && j < NY && k >= 0 && k < NZ) {
        int materialHy = ID[INDEX4D_ID(4,i_ID,j_ID,k_ID)];
        Hy[INDEX3D_FIELDS(i,j,k)] = updatecoeffsH[INDEX2D_MAT(materialHy,0)] * Hy[INDEX3D_FIELDS(i,j,k)] - updatecoeffsH[INDEX2D_MAT(materialHy,3)] * (Ex[INDEX3D_FIELDS(i,j,k+1)] - Ex[INDEX3D_FIELDS(i,j,k)]) + updatecoeffsH[INDEX2D_MAT(materialHy,1)] * (Ez[INDEX3D_FIELDS(i+1,j,k)] - Ez[INDEX3D_FIELDS(i,j,k)]);
    }

    // Hz component
    if (NZ != 1 && i >= 0 && i < NX && j >= 0 && j < NY && k > 0 && k < NZ) {
        int materialHz = ID[INDEX4D_ID(5,i_ID,j_ID,k_ID)];
        Hz[INDEX3D_FIELDS(i,j,k)] = updatecoeffsH[INDEX2D_MAT(materialHz,0)] * Hz[INDEX3D_FIELDS(i,j,k)] - updatecoeffsH[INDEX2D_MAT(materialHz,1)] * (Ey[INDEX3D_FIELDS(i+1,j,k)] - Ey[INDEX3D_FIELDS(i,j,k)]) + updatecoeffsH[INDEX2D_MAT(materialHz,2)] * (Ex[INDEX3D_FIELDS(i,j+1,k)] - Ex[INDEX3D_FIELDS(i,j,k)]);
    }
}